import UIKit

protocol SentryMaskRenderer {
    func maskScreenshot(screenshot image: UIImage, size: CGSize, masking: [RedactRegion]) -> UIImage
}
