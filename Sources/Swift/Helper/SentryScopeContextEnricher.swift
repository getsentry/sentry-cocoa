// swiftlint:disable file_length missing_docs
internal import _SentryPrivate
import CommonCrypto
import Darwin
import Foundation

@objc @_spi(Private) public protocol SentryScopeContextEnricher {
    func enrichScope(_ scope: Scope)
}

struct SentrySystemInfo {
    let systemName: String
    let osBuild: String
    let kernelVersion: String
    let isJailbroken: Bool
    let cpuArchitecture: String
    let machine: String?
    let model: String?
    let freeMemorySize: UInt64
    let usableMemorySize: UInt64
    let memorySize: UInt64
    let appStartTime: String
    let deviceAppHash: String
    let appID: String?
    let buildType: String
}

protocol SentrySystemInfoProvider: AnyObject {
    func systemInfo() -> SentrySystemInfo
}

final class SentryDefaultSystemInfoProvider: SentrySystemInfoProvider {
    private let memoryMetricsProvider: SentryMemoryMetricsProvider
    private let binaryImageCache: SentryBinaryImageCache
    private let bundle: Bundle
    private let vendorIdentifierProvider: (() -> UUID?)?
    private let appStartTime: String

    init(
        memoryMetricsProvider: SentryMemoryMetricsProvider,
        binaryImageCache: SentryBinaryImageCache,
        dateProvider: SentryCurrentDateProvider,
        bundle: Bundle = .main,
        vendorIdentifierProvider: (() -> UUID?)? = nil
    ) {
        self.memoryMetricsProvider = memoryMetricsProvider
        self.binaryImageCache = binaryImageCache
        self.bundle = bundle
        self.vendorIdentifierProvider = vendorIdentifierProvider
        self.appStartTime = Self.iso8601DateString(dateProvider.date())
    }

    func systemInfo() -> SentrySystemInfo {
        let images = binaryImageCache.getAllBinaryImages()
        return SentrySystemInfo(
            systemName: Self.systemName,
            osBuild: Self.sysctlString("kern.osversion"),
            kernelVersion: Self.sysctlString("kern.version"),
            isJailbroken: images.contains { $0.name.contains("MobileSubstrate") },
            cpuArchitecture: Self.cpuArchitecture,
            machine: Self.machine,
            model: Self.model,
            freeMemorySize: memoryMetricsProvider.freeMemorySize,
            usableMemorySize: memoryMetricsProvider.usableMemorySize,
            memorySize: memoryMetricsProvider.totalMemorySize,
            appStartTime: appStartTime,
            deviceAppHash: deviceAppHash(),
            appID: appID(from: images),
            buildType: Self.buildType
        )
    }

    private func appID(from images: [SentryBinaryImageInfo]) -> String? {
        guard let executablePath = bundle.executablePath else {
            return nil
        }
        if let exactImage = images.first(where: { $0.name == executablePath }) {
            return exactImage.uuid
        }
        let executableName = URL(fileURLWithPath: executablePath).lastPathComponent
        return images.first { $0.name.contains(executableName) }?.uuid
    }

    private func deviceAppHash() -> String {
        var data: Data
        if let vendorIdentifierProvider {
            var uuid = vendorIdentifierProvider()?.uuid ?? Self.zeroedUUID
            data = withUnsafeBytes(of: &uuid) { Data($0) }
        } else {
            data = Data(Self.macAddress(interface: "en0") ?? [UInt8](repeating: 0, count: 6))
        }

        data.append(Self.sysctlString("hw.machine").data(using: .utf8) ?? Data())
        data.append(Self.sysctlString("hw.model").data(using: .utf8) ?? Data())
        if let bundleIdentifier = bundle.bundleIdentifier {
            data.append(bundleIdentifier.data(using: .utf8) ?? Data())
        }

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA1(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static var systemName: String {
#if os(macOS) || targetEnvironment(macCatalyst)
        return "macOS"
#elseif os(iOS)
        return "iOS"
#elseif os(tvOS)
        return "tvOS"
#elseif os(watchOS)
        return "watchOS"
#elseif os(visionOS)
        return "visionOS"
#endif
    }

    private static var machine: String? {
#if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
#elseif os(macOS)
        return sysctlString("hw.model")
#else
        return sysctlString("hw.machine")
#endif
    }

    private static var model: String? {
#if targetEnvironment(simulator)
        return "simulator"
#elseif os(macOS)
        return nil
#else
        return sysctlString("hw.model")
#endif
    }

    private static var cpuArchitecture: String {
        var cpuType: cpu_type_t = 0
        var cpuTypeSize = MemoryLayout<cpu_type_t>.size
        if sysctlbyname("hw.cputype", &cpuType, &cpuTypeSize, nil, 0) == 0 {
            switch cpuType {
            case CPU_TYPE_ARM64, CPU_TYPE_ARM64_32:
                return "arm64"
            case CPU_TYPE_ARM:
                var cpuSubtype: cpu_subtype_t = 0
                var cpuSubtypeSize = MemoryLayout<cpu_subtype_t>.size
                if sysctlbyname("hw.cpusubtype", &cpuSubtype, &cpuSubtypeSize, nil, 0) == 0 {
                    switch cpuSubtype {
                    case CPU_SUBTYPE_ARM_V6:
                        return "armv6"
                    case CPU_SUBTYPE_ARM_V7:
                        return "armv7"
                    case CPU_SUBTYPE_ARM_V7F:
                        return "armv7f"
                    case CPU_SUBTYPE_ARM_V7K:
                        return "armv7k"
                    case CPU_SUBTYPE_ARM_V7S:
                        return "armv7s"
                    default:
                        break
                    }
                }
                return "arm"
            case CPU_TYPE_X86_64:
                return "x86_64"
            case CPU_TYPE_X86:
                return "x86"
            default:
                break
            }
        }
#if arch(arm64) || arch(arm64_32)
        return "arm64"
#elseif arch(arm)
        return "arm"
#elseif arch(x86_64)
        return "x86_64"
#elseif arch(i386)
        return "x86"
#endif
    }

    private static var zeroedUUID: uuid_t {
        (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    private static var buildType: String {
#if targetEnvironment(simulator)
        return "simulator"
#elseif DEBUG
        return "debug"
#else
        let parser = SentryMobileProvisionParser()
        if parser.hasEmbeddedMobileProvisionProfile() {
            if parser.mobileProvisionProfileAllowsDebugging {
                return "debug"
            }
            return parser.mobileProvisionProfileProvisionsAllDevices ? "enterprise" : "adhoc"
        }
#if os(iOS)
        let receiptURL = Bundle.main.appStoreReceiptURL
        if receiptURL?.lastPathComponent == "sandboxReceipt" {
            return "test"
        }
        if receiptURL?.lastPathComponent == "receipt",
           let receiptURL,
           FileManager.default.fileExists(atPath: receiptURL.path) {
            return "app store"
        }
#endif
        return "unknown"
#endif
    }

    private static func iso8601DateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return formatter.string(from: date)
    }

    private static func sysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
            return ""
        }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else {
            return ""
        }
        return String(cString: value)
    }

    private static func macAddress(interface: String) -> [UInt8]? {
        let interfaceIndex = if_nametoindex(interface)
        guard interfaceIndex != 0 else {
            return nil
        }

        var mib = [CTL_NET, AF_ROUTE, 0, AF_LINK, NET_RT_IFLIST, Int32(interfaceIndex)]
        var size = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > 0 else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: size)
        let result = buffer.withUnsafeMutableBytes { bytes in
            sysctl(&mib, u_int(mib.count), bytes.baseAddress, &size, nil, 0)
        }
        guard result == 0 else {
            return nil
        }

        return macAddress(from: buffer, byteCount: min(size, buffer.count))
    }

    private static func macAddress(from buffer: [UInt8], byteCount: Int) -> [UInt8]? {
        buffer.withUnsafeBytes { bytes -> [UInt8]? in
            guard let baseAddress = bytes.baseAddress,
                  let dataOffset = MemoryLayout<sockaddr_dl>.offset(of: \.sdl_data) else {
                return nil
            }

            let messageHeaderSize = MemoryLayout<if_msghdr>.stride
            let linkAddressSize = MemoryLayout<sockaddr_dl>.size
            guard byteCount >= messageHeaderSize + linkAddressSize else {
                return nil
            }

            let messageHeader = baseAddress.assumingMemoryBound(to: if_msghdr.self)
            let messageLength = Int(messageHeader.pointee.ifm_msglen)
            guard messageLength >= messageHeaderSize + linkAddressSize,
                  messageLength <= byteCount else {
                return nil
            }

            let linkAddress = baseAddress
                .advanced(by: messageHeaderSize)
                .assumingMemoryBound(to: sockaddr_dl.self)
            let linkAddressLength = Int(linkAddress.pointee.sdl_len)
            let interfaceNameLength = Int(linkAddress.pointee.sdl_nlen)
            let hardwareAddressLength = Int(linkAddress.pointee.sdl_alen)
            guard Int(linkAddress.pointee.sdl_family) == AF_LINK,
                  hardwareAddressLength >= 6,
                  linkAddressLength >= dataOffset,
                  interfaceNameLength <= linkAddressLength - dataOffset,
                  linkAddressLength - dataOffset - interfaceNameLength >= 6,
                  linkAddressLength <= messageLength - messageHeaderSize else {
                return nil
            }

            let addressOffset = messageHeaderSize + dataOffset + interfaceNameLength
            let address = baseAddress.advanced(by: addressOffset).assumingMemoryBound(to: UInt8.self)
            return Array(UnsafeBufferPointer(start: address, count: 6))
        }
    }
}

final class SentryDefaultScopeContextEnricher: NSObject, SentryScopeContextEnricher {
    typealias OSVersionProvider = () -> String
    typealias ScreenSizeProvider = () -> CGSize

    private let processInfoWrapper: SentryProcessInfoSource
    private let systemInfoProvider: SentrySystemInfoProvider
    private let bundleInfo: [String: Any]
    private let osVersionProvider: OSVersionProvider
    private let screenSizeProvider: ScreenSizeProvider

    init(
        processInfoWrapper: SentryProcessInfoSource,
        systemInfoProvider: SentrySystemInfoProvider,
        bundleInfo: [String: Any] = Bundle.main.infoDictionary ?? [:],
        osVersionProvider: @escaping OSVersionProvider,
        screenSizeProvider: @escaping ScreenSizeProvider = { .zero }
    ) {
        self.processInfoWrapper = processInfoWrapper
        self.systemInfoProvider = systemInfoProvider
        self.bundleInfo = bundleInfo
        self.osVersionProvider = osVersionProvider
        self.screenSizeProvider = screenSizeProvider
    }

    func enrichScope(_ scope: Scope) {
        let systemInfo = systemInfoProvider.systemInfo()
        enrichScopeWithOSData(scope, systemInfo: systemInfo)
        enrichScopeWithDeviceData(scope, systemInfo: systemInfo)
        enrichScopeWithAppData(scope, systemInfo: systemInfo)
        enrichScopeWithRuntimeData(scope)
    }

    private func enrichScopeWithOSData(_ scope: Scope, systemInfo: SentrySystemInfo) {
        scope.setContext(value: [
            "name": systemInfo.systemName,
            "version": osVersionProvider(),
            "build": systemInfo.osBuild,
            "kernel_version": systemInfo.kernelVersion,
            "rooted": systemInfo.isJailbroken
        ], key: "os")
    }

    private func enrichScopeWithDeviceData(_ scope: Scope, systemInfo: SentrySystemInfo) {
        var deviceData: [String: Any] = [
            "simulator": Self.isSimulator,
            "family": Self.deviceFamily(from: systemInfo.systemName),
            "arch": systemInfo.cpuArchitecture,
            "free_memory": systemInfo.freeMemorySize,
            "usable_memory": systemInfo.usableMemorySize,
            "memory_size": systemInfo.memorySize
        ]
        deviceData["model"] = systemInfo.machine
        deviceData["model_id"] = systemInfo.model

#if !SDK_V10
        deviceData["locale"] = Locale.autoupdatingCurrent.identifier
#endif

        if processInfoWrapper.isiOSAppOnMac {
            deviceData["ios_app_on_macos"] = true
        }
        if processInfoWrapper.isMacCatalystApp {
            deviceData["mac_catalyst_app"] = true
        }
        if processInfoWrapper.isiOSAppOnVisionOS {
            deviceData["ios_app_on_visionos"] = true
        }

        let screenSize = screenSizeProvider()
        if screenSize != .zero {
            deviceData["screen_height_pixels"] = screenSize.height
            deviceData["screen_width_pixels"] = screenSize.width
        }

        scope.setContext(value: deviceData, key: "device")
    }

    private func enrichScopeWithAppData(_ scope: Scope, systemInfo: SentrySystemInfo) {
        var appData: [String: Any] = [
            "app_start_time": systemInfo.appStartTime,
            "device_app_hash": systemInfo.deviceAppHash,
            "build_type": systemInfo.buildType
        ]
        appData["app_identifier"] = bundleInfo["CFBundleIdentifier"]
        appData["app_name"] = bundleInfo["CFBundleName"]
        appData["app_build"] = bundleInfo["CFBundleVersion"]
        appData["app_version"] = bundleInfo["CFBundleShortVersionString"]
        appData["app_id"] = systemInfo.appID
        scope.setContext(value: appData, key: "app")
    }

    private func enrichScopeWithRuntimeData(_ scope: Scope) {
        var runtimeContext: [String: Any] = [:]
        if processInfoWrapper.isiOSAppOnMac {
            runtimeContext["name"] = "iOS App on Mac"
            runtimeContext["raw_description"] = "ios-app-on-mac"
        }
        if processInfoWrapper.isMacCatalystApp {
            runtimeContext["name"] = "Mac Catalyst App"
            runtimeContext["raw_description"] = "mac-catalyst-app"
        }
        if !runtimeContext.isEmpty {
            scope.setContext(value: runtimeContext, key: "runtime")
        }
    }

    private static var isSimulator: Bool {
#if targetEnvironment(simulator)
        return true
#else
        return false
#endif
    }

    private static func deviceFamily(from systemName: String) -> String {
#if targetEnvironment(macCatalyst)
        return "macOS"
#else
        return systemName.components(separatedBy: .whitespacesAndNewlines).first ?? systemName
#endif
    }
}
// swiftlint:enable file_length missing_docs
