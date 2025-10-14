@_spi(Private) @objc public protocol SentryProcessInfoSource {
    var processDirectoryPath: String { get }
    var processPath: String? { get }
    var processorCount: Int { get }
    var thermalState: ProcessInfo.ThermalState { get }
    var environment: [String: String] { get }
    
    var isiOSAppOnMac: Bool { get }
    
    var isMacCatalystApp: Bool { get }
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
}
