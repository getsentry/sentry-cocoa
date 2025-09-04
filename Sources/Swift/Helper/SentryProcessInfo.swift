@_spi(Private) @objc public protocol SentryProcessInfo {
    var processDirectoryPath: String { get }
    var processPath: String? { get }
    var processorCount: Int { get }
    var thermalState: ProcessInfo.ThermalState { get }
    var environment: [String: String] { get }
    
    @available(iOS 14.0, macOS 11.0, watchOS 7.0, tvOS 14.0, *)
    var isiOSAppOnMac: Bool { get }
    
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    var isMacCatalystApp: Bool { get }
}

@_spi(Private) extension ProcessInfo: SentryProcessInfo {
    public var processDirectoryPath: String {
        Bundle.main.bundlePath
    }
    
    public var processPath: String? {
        Bundle.main.executablePath
    }
}
