@_spi(Private) @objc public protocol SentryProcessInfoSource {
    var processDirectoryPath: String { get }
    var processPath: String? { get }
    var processorCount: Int { get }
    var thermalState: ProcessInfo.ThermalState { get }
    var environment: [String: String] { get }

    @available(macOS 12.0, *)
    var isiOSAppOnMac: Bool { get }

    @available(macOS 12.0, *)
    var isMacCatalystApp: Bool { get }
    
    var isiOSAppOnVisionOS: Bool { get }
}

// This is needed because a file that only contains an @objc extension will get automatically stripped out
// in static builds. We need to either use the -all_load linker flag (which has downsides of app size increases)
// or make sure that every file containing objc categories/extensions also have a concrete type that
// is referenced. Once `SentryProcessInfoSource` is not using `@objc` this can be removed.
@_spi(Private) @objc public final class PlaceholderProcessInfoClass: NSObject { }

@_spi(Private) extension ProcessInfo: SentryProcessInfoSource {
    public var processDirectoryPath: String {
        Bundle.main.bundlePath
    }
    
    public var processPath: String? {
        Bundle.main.executablePath
    }
    
    public var isiOSAppOnVisionOS: Bool {
        if #available(iOS 26.1, visionOS 26.1, *) {
            // Use official API when available
            // https://developer.apple.com/documentation/foundation/processinfo/isiosapponvision
            //
            // For unknown reasons when running an iOS app "Designed for iPad" on visionOS 1.1, the simulator system
            // version is simulator 17.4, but it still enters this block.
            //
            // Due to that it crashes with an uncaught exception 'NSInvalidArgumentException', reason: '-[NSProcessInfo isiOSAppOnVision]: unrecognized selector sent to instance 0x600001549230'
            if self.responds(to: NSSelectorFromString("isiOSAppOnVision")) {
                // Use value(forKey:) to dynamically access the property at runtime
                // This avoids compile-time errors when the API isn't available in the SDK headers of Xcode 16 or older.
                //
                // It's important to keep this approach as long as we support compiling with Xcode 16,
                // because users might compile the SDK locally using Xcode 16 via SPM or other distribution methods.
                if let value = self.value(forKey: "isiOSAppOnVision") as? Bool {
                    return value
                }
            }
        }
        // Fallback for older visionOS versions (< 26.1) when the official API isn't available.
        // The `#if os(iOS)` check is necessary because `UIWindowSceneGeometryPreferencesVision` exists on all
        // visionOS builds, so without this compile-time check, native visionOS apps would incorrectly return `true`.
        #if os(iOS)
        // https://developer.apple.com/documentation/uikit/uiwindowscene/geometrypreferences/vision?language=objc
        return NSClassFromString("UIWindowSceneGeometryPreferencesVision") != nil
        #else
        return false
        #endif
    }
}
