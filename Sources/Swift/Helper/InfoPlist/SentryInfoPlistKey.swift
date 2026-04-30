enum SentryInfoPlistKey: String {
    /// The extension configuration dictionary for app extensions
    ///
    /// - SeeAlso: [Apple Documentation](https://developer.apple.com/documentation/bundleresources/information_property_list/nsextension)
    case `extension` = "NSExtension"
    
    /// Keys within the NSExtension dictionary
    enum Extension: String {
        /// The extension point identifier that specifies the type of app extension
        ///
        /// - SeeAlso: [Apple Documentation](https://developer.apple.com/documentation/bundleresources/information_property_list/nsextension/nsextensionpointidentifier)
        case pointIdentifier = "NSExtensionPointIdentifier"
    }
}
