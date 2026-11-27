/// Extension point identifiers for common iOS extension types
@_spi(Private) @objc
public enum SentryExtensionType: Int {
    /// WidgetKit extensions (includes Widgets and Live Activities)
    case widget
    /// Intents extensions
    case intent
    /// Action extensions (share, today, etc.)
    case action
    /// Share extensions
    case share
    /// Notification Service extensions
    case notificationService
    /// Contact Provider extensions, which are ExtensionKit extensions
    case contactProvider

    /// Returns the extension point identifier string for this extension type, which is the
    /// `NSExtensionPointIdentifier`, or the `EXExtensionPointIdentifier` for ExtensionKit extensions
    public var identifier: String {
        switch self {
        case .widget:
            return "com.apple.widgetkit-extension"
        case .intent:
            return "com.apple.intents-service"
        case .action:
            return "com.apple.ui-services"
        case .share:
            return "com.apple.share-services"
        case .notificationService:
            return "com.apple.usernotifications.service"
        case .contactProvider:
            return "com.apple.contact.provider.extension"
        }
    }
}
