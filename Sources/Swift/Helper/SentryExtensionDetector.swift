import Foundation

/// Detects if the current process is running in any extension where app hang tracking should be disabled.
extension String {
    var isDisabledExtensionPointIdentifier: Bool {
        return SentryExtensionDetector.disabledAppHangTypes.contains { $0.identifier == self }
    }
}

final class SentryExtensionDetector: NSObject {
    /// All extension types where app hang tracking should be disabled
    fileprivate static var disabledAppHangTypes: [SentryExtensionType] {
        return [
            .widget,
            .intent,
            .action,
            .share,
            .notificationService,
            .contactProvider
        ]
    }

    private let infoPlistWrapper: SentryInfoPlistWrapperProvider
    
    init(infoPlistWrapper: SentryInfoPlistWrapperProvider) {
        self.infoPlistWrapper = infoPlistWrapper
        super.init()
    }
    
    /// Returns the extension point identifier from the Bundle's Info.plist, if present.
    ///
    /// Foundation extensions declare it as `NSExtension` › `NSExtensionPointIdentifier`, ExtensionKit extensions
    /// as `EXAppExtensionAttributes` › `EXExtensionPointIdentifier`.
    func getExtensionPointIdentifier() -> String? {
        return getPointIdentifier(
            dictionaryKey: SentryInfoPlistKey.extension.rawValue,
            pointIdentifierKey: SentryInfoPlistKey.Extension.pointIdentifier.rawValue
        ) ?? getPointIdentifier(
            dictionaryKey: SentryInfoPlistKey.extensionKitAttributes.rawValue,
            pointIdentifierKey: SentryInfoPlistKey.ExtensionKitAttributes.pointIdentifier.rawValue
        )
    }

    private func getPointIdentifier(dictionaryKey: String, pointIdentifierKey: String) -> String? {
        do {
            let extensionDict = try infoPlistWrapper.getAppValueDictionary(for: dictionaryKey)
            // The point identifier can be missing from the dictionary
            return extensionDict[pointIdentifierKey] as? String
        } catch SentryInfoPlistError.mainInfoPlistNotFound {
            // Info.plist not found - not an extension
            return nil
        } catch SentryInfoPlistError.keyNotFound {
            // Dictionary key not found - not an extension of this kind
            return nil
        } catch SentryInfoPlistError.unableToCastValue(let key, let value, let type) {
            SentrySDKLog.error("Failed to cast \(dictionaryKey) value for key '\(key)': \(value) to type \(type)")
            return nil
        } catch {
            SentrySDKLog.error("Unexpected error reading extension info from Info.plist: \(error)")
            return nil
        }
    }
}
