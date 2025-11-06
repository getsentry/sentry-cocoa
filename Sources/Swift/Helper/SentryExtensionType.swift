/// Extension point identifiers for common iOS extension types
@_spi(Private) @objc
public enum SentryExtensionType: Int {
    /// WidgetKit extensions (includes Widgets and Live Activities)
    case widget
    /// Intents extensions
    case intent
    /// Action extensions (share, today, etc.)
    case action
    
    /// Returns the NSExtensionPointIdentifier string for this extension type
    public var identifier: String {
        switch self {
        case .widget:
            return "com.apple.widgetkit-extension"
        case .intent:
            return "com.apple.intents-service"
        case .action:
            return "com.apple.ui-services"
        }
    }
}
