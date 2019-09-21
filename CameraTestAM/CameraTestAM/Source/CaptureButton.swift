import Foundation
import UIKit

protocol CaptureButtonDelegate: AnyObject {

    func captureButtonTapped(_ button: CaptureButton)

}

final class CaptureButton: UIView {

    var defaultSize: CGFloat = 60

    var originalTransform: CGAffineTransform?

    weak var delegate: CaptureButtonDelegate?

    func setupAppearence() {
        self.backgroundColor = UIColor.white
        self.frame = CGRect(x: 0,
                            y: 0,
                            width: defaultSize,
                            height: defaultSize)
        self.layer.cornerRadius = self.layer.frame.width / 2
        originalTransform = self.transform
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let originalTransform = self.originalTransform else {
            return
        }
        let scaledTransform = originalTransform.scaledBy(x: 1.5, y: 1.5)
        let scaledAndTranslatedTransform = scaledTransform.translatedBy(x: 0.0, y: 0.0)
        UIView.animate(withDuration: 0.3, animations: {
            self.transform = scaledAndTranslatedTransform
        })
    }

    func resizeToDefaults() {
        guard let originalTransform = self.originalTransform else {
            return
        }
        UIView.animate(withDuration: 0.3, animations: {
            self.transform = originalTransform
        })
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.delegate?.captureButtonTapped(self)
        resizeToDefaults()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let originalTransform = self.originalTransform {
            self.transform = originalTransform
            resizeToDefaults()
        }
    }
    

}
