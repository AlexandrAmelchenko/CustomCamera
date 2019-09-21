import UIKit
import Photos

class ViewController: UIViewController {

    var captureButtonView = CaptureButton(frame: CGRect(x: 0,
                                                 y: 0,
                                                 width: 0,
                                                 height: 0))

    @IBOutlet weak var gesturesView: UIView! {
        didSet {
            gesturesView.backgroundColor = UIColor.clear
        }
    }

    @IBOutlet weak var filteredImageView: UIImageView!
    
    override var prefersStatusBarHidden: Bool { return true }
    
    let cameraController = CameraController()
    
    func bringButtonsToFront() {
        self.view.bringSubviewToFront(filteredImageView)
        self.view.bringSubviewToFront(captureButtonView)
    }

    @IBAction func swipeLeftHandler(_ gestureRecognizer : UISwipeGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            cameraController.switchToNextFilter()
        }
    }

    @IBAction func swipeRightHandler(_ gestureRecognizer : UISwipeGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            cameraController.switchToPreviousFilter()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        func configureCameraController() {
            cameraController.prepare {(error) in
                if let error = error {
                    print(error)
                }
                self.cameraController.previewImageView = self.filteredImageView
            }
        }
        self.view.addSubview(captureButtonView)
        captureButtonView.delegate = self
        configureCameraController()
        bringButtonsToFront()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        captureButtonView.setupAppearence()
        captureButtonView.center = CGPoint(x: layerSize().width / 2,
                              y: layerSize().height - 90)
    }


}

extension ViewController: CaptureButtonDelegate {

    func captureButtonTapped(_ button: CaptureButton) {
        cameraController.captureImage {(image, error) in
            guard let image = image else {
                print(error ?? "Image capture error")
                return
            }
            try? PHPhotoLibrary.shared().performChangesAndWait {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        }
    }

}

