import Foundation
import AVFoundation
import UIKit

class CameraController: NSObject {
    
    enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    var captureSession: AVCaptureSession?
    var rearCamera: AVCaptureDevice?
    var rearCameraInput: AVCaptureDeviceInput?
    var photoOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    let context = CIContext()
    var orientation = AVCaptureVideoOrientation.portrait
    var previewImageView: UIImageView?
    let filterManager = FilterManager()
    
    func prepare(completionHandler: @escaping (Error?) -> Void) {

        func createCaptureSession() {
            self.captureSession = AVCaptureSession()
        }

        func configureCaptureDevices() throws {
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
            let cameras = (session.devices.compactMap { $0 })
            if cameras.count == 0 {
                //todo: handle this case
            }
            for camera in cameras {
                if camera.position == .back {
                    self.rearCamera = camera
                    try camera.lockForConfiguration()
                    camera.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
        }

        func configureDeviceInputs() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            if let rearCamera = self.rearCamera {
                setupCorrectFramerate(currentCamera: rearCamera)
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                if let rearCameraInput = self.rearCameraInput {
                    if captureSession.canAddInput(rearCameraInput) { captureSession.addInput(rearCameraInput) }
                }
            } else { throw CameraControllerError.noCamerasAvailable }
        }

        func configurePhotoOutput() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer delegate", attributes: []))
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
            self.photoOutput = AVCapturePhotoOutput()
            if let photoOutput = self.photoOutput {
                photoOutput.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])],
                                                          completionHandler: nil)
                if captureSession.canAddOutput(photoOutput) { captureSession.addOutput(photoOutput) }
                captureSession.startRunning()
            }
            captureSession.startRunning()
        }

        DispatchQueue(label: "prepare").async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configurePhotoOutput()
            }
            catch {
                DispatchQueue.main.async {
                    completionHandler(error)
                }
                return
            }
            DispatchQueue.main.async {
                completionHandler(nil)
            }
        }
    }

    func setupCorrectFramerate(currentCamera: AVCaptureDevice) {
        for vFormat in currentCamera.formats {
            var ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
            let frameRates = ranges[0]
            do {
                if frameRates.maxFrameRate == 240 {
                    try currentCamera.lockForConfiguration()
                    currentCamera.activeFormat = vFormat as AVCaptureDevice.Format
                    currentCamera.activeVideoMinFrameDuration = frameRates.minFrameDuration
                    currentCamera.activeVideoMaxFrameDuration = frameRates.maxFrameDuration
                }
            }
            catch {
                print("Could not set active format")
                print(error)
            }
        }
    }
    
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        guard let captureSession = captureSession,
            captureSession.isRunning else { completion(nil, CameraControllerError.captureSessionIsMissing); return }
        let settings = AVCapturePhotoSettings()
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        self.photoCaptureCompletionBlock = completion
    }
    
    func switchToNextFilter() {
        self.filterManager.switchToNextFilter()
    }

    func switchToPreviousFilter() {
        self.filterManager.switchTopreviousFilter()
    }
    
}

extension CameraController: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error { self.photoCaptureCompletionBlock?(nil, error) }
        else if let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data) {
            if let effect = self.filterManager.selectedFilter() {
                let orientation32 = imageOrientationToTiffOrientation(image.imageOrientation)
                let cameraImage = CIImage(image: image)?.oriented(forExifOrientation: orientation32)
                effect.setValue(cameraImage, forKey: kCIInputImageKey)
                guard let image = effect.outputImage else { return }
                if let cgimg = context.createCGImage(image, from: image.extent) {
                    let processedImage = UIImage(cgImage: cgimg)
                    self.photoCaptureCompletionBlock?(processedImage, nil)
                }
            } else {
                self.photoCaptureCompletionBlock?(image, nil)
            }
        }
        else {
            self.photoCaptureCompletionBlock?(nil, CameraControllerError.unknown)
        }
    }

    func imageOrientationToTiffOrientation(_ value: UIImage.Orientation) -> Int32
    {
        switch (value)
        {
        case .up:
            return 1
        case .down:
            return 3
        case .left:
            return 8
        case .right:
            return 6
        case .upMirrored:
            return 2
        case .downMirrored:
            return 4
        case .leftMirrored:
            return 5
        case .rightMirrored:
            return 7
        }
    }

}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        connection.videoOrientation = orientation
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)

        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let cameraImage = CIImage(cvImageBuffer: pixelBuffer!)

        if let filter = filterManager.selectedFilter() {
            filter.setValue(cameraImage, forKey: kCIInputImageKey)
            if let outputImage = filter.outputImage {
                let cgImage = self.context.createCGImage(outputImage, from: cameraImage.extent)!
                let filteredImage = UIImage(cgImage: cgImage)
                DispatchQueue.main.async {
                    self.previewImageView?.image = filteredImage
                }
            }
        } else {
            let filteredImage = UIImage(ciImage: cameraImage)
            DispatchQueue.main.async {
                self.previewImageView?.image = filteredImage
            }
        }
    }

}
