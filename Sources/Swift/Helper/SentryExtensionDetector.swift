import Foundation

@_spi(Private) public final class SentryExtensionDetector: NSObject {
    /// All extension types where app hang tracking should be disabled
    private static var disabledAppHangTypes: [SentryExtensionType] {
        return [.widget, .intent, .action, .share]
    }

    private let infoPlistWrapper: SentryInfoPlistWrapperProvider
    
    init(infoPlistWrapper: SentryInfoPlistWrapperProvider) {
        self.infoPlistWrapper = infoPlistWrapper
        super.init()
    }
    
    /// Detects if the current process is running in any extension where app hang tracking should be disabled.
    @objc public func shouldDisableAppHangTracking() -> Bool {
        guard let extensionPointIdentifier = getExtensionPointIdentifier() else {
            return false
        }
        return Self.disabledAppHangTypes.contains { $0.identifier == extensionPointIdentifier }
    }
    
    /// Returns the NSExtensionPointIdentifier from the Bundle's Info.plist, if present.
    @objc public func getExtensionPointIdentifier() -> String? {
        do {
            let extensionDict = try infoPlistWrapper.getAppValueDictionary(
                for: SentryInfoPlistKey.extension.rawValue
            )
            guard let pointIdentifier = extensionDict[SentryInfoPlistKey.Extension.pointIdentifier.rawValue] as? String else {
                // NSExtensionPointIdentifier not found in NSExtension dictionary
                return nil
            }
            return pointIdentifier
        } catch SentryInfoPlistError.mainInfoPlistNotFound {
            // Info.plist not found - not an extension
            return nil
        } catch SentryInfoPlistError.keyNotFound {
            // NSExtension key not found - not an extension
            return nil
        } catch SentryInfoPlistError.unableToCastValue(let key, let value, let type) {
            SentrySDKLog.error("Failed to cast NSExtension value for key '\(key)': \(value) to type \(type)")
            return nil
        } catch {
            SentrySDKLog.error("Unexpected error reading extension info from Info.plist: \(error)")
            return nil
        }
    }
}
