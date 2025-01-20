import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import PhotosUI
import UIKit

@available(iOS 13.0, *)
protocol SentryPhotoPickerDelegate: NSObjectProtocol {
    func chose(image: UIImage, accessibilityInfo: String)
}

@available(iOS 13.0, *)
class SentryPhotoPicker: NSObject {
    weak var delegate: SentryPhotoPickerDelegate?
    
    let formatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    
    public func display(config: SentryUserFeedbackConfiguration, presenter: UIViewController & SentryPhotoPickerDelegate) {
        func presentPicker() {
            delegate = presenter
            
            let imagePickerController = UIImagePickerController()
            imagePickerController.delegate = self
            imagePickerController.sourceType = .photoLibrary
            imagePickerController.allowsEditing = true
            DispatchQueue.main.async {
                presenter.present(imagePickerController, animated: config.animations)
            }
        }
        
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            if #available(iOS 14, *) {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) {
                    SentryLog.debug("Photos authorization level: \($0)")
                    presentPicker()
                }
            } else {
                PHPhotoLibrary.requestAuthorization {
                    SentryLog.debug("Photos authorization level: \($0)")
                    presentPicker()
                }
            }
        default:
            SentryLog.debug("Photos authorization level: \(status)")
            presentPicker()
        }

    }
}

// MARK: UIImagePickerControllerDelegate & UINavigationControllerDelegate
@available(iOS 13.0, *)
extension SentryPhotoPicker: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let photo = info[.editedImage] as? UIImage else {
            SentryLog.warning("Could not get edited image from photo picker.")
            return
        }
        
        func accessibilityInfo() -> String {
            guard let asset = info[.phAsset] as? PHAsset else {
                SentryLog.warning("Could not get edited image asset information from photo picker.")
                return "Image"
            }
            guard let date = asset.creationDate else {
                SentryLog.warning("Could not get creation date from edited image from photo picker.")
                return "Image"
            }
            return "Image taken \(formatter.string(from: date))"
        }
        
        delegate?.chose(image: photo, accessibilityInfo: accessibilityInfo())
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
