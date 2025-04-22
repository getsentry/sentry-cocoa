import UIKit

public enum ToastType {
    case info
    case success
    case warning
    case error
}

public func showToast(in vc: UIViewController, type: ToastType, message: String) {
    let title: String
    var action: UIAlertAction?
    switch type {
    case .info:
        title = "OBTW"
    case .success:
        title = "Success!"
    case .warning:
        title = "Warning"
        action = .init(title: "OK", style: .default, handler: { _ in
            
        })
    case .error:
        title = "Error"
        action = .init(title: "OK", style: .default, handler: { _ in
            
        })
    }
    let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
    if let action = action {
        alert.addAction(action)
    }
    vc.present(alert, animated: true) {
        switch type {
        case .info, .success:
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                vc.dismiss(animated: true)
            }
        default: break
        }
    }
}
