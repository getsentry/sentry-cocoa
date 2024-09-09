import SwiftMessages

@MainActor func showToast(in view: UIView, type: Theme, message: String) {
    let view = MessageView.viewFromNib(layout: .statusLine)
    view.configureTheme(type)
    let iconText: String
    let title: String
    switch type {
    case .info: 
        title = "OBTW"
        iconText = "ℹ️"
    case .success: 
        title = "Success!"
        iconText = "🥳"
    case .warning: 
        title = "Warning"
        iconText = "⚠️"
    case .error:
        title = "Error"
        iconText = "🤡"
    }
    view.configureContent(title: title, body: message, iconText: iconText)
    
    view.layoutMarginAdditions = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
    (view.backgroundView as? CornerRoundingView)?.cornerRadius = 10
    
    SwiftMessages.show(view: view)
}
