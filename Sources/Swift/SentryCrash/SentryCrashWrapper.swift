// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Darwin
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

/**
 * A wrapper around SentryCrash for testability.
 */
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
@objc @_spi(Private)
public class SentryCrashWrapper: NSObject {
    let processInfoWrapper: SentryProcessInfoSource
    private let bridge: SentryCrashBridge

    @objc
    public let systemInfo: [String: Any]

    @objc
    public init(processInfoWrapper: SentryProcessInfoSource, bridge: SentryCrashBridge) {
        self.processInfoWrapper = processInfoWrapper
        self.bridge = bridge
        self.systemInfo = bridge.crashReporter.systemInfo as? [String: Any] ?? [:]
        super.init()
        sentrycrashcm_system_getAPI()?.pointee.setEnabled(true)
    }

#if SENTRY_TEST || SENTRY_TEST_CI
    // This var and initializer are used to inject system info during tests
    public init(processInfoWrapper: SentryProcessInfoSource, systemInfo: [String: Any], bridge: SentryCrashBridge) {
        self.processInfoWrapper = processInfoWrapper
        self.bridge = bridge
        self.systemInfo = systemInfo
        super.init()
    }
#endif // SENTRY_TEST && SENTRY_TEST_CI
}
#else
@objc @_spi(Private)
public final class SentryCrashWrapper: NSObject {
    let processInfoWrapper: SentryProcessInfoSource
    private let bridge: SentryCrashBridge

    @objc
    public let systemInfo: [String: Any]

    @objc
    public init(processInfoWrapper: SentryProcessInfoSource, bridge: SentryCrashBridge) {
        self.processInfoWrapper = processInfoWrapper
        self.bridge = bridge
        self.systemInfo = bridge.crashReporter.systemInfo as? [String: Any] ?? [:]
        super.init()
        // Always enable crash monitoring on release builds
        sentrycrashcm_system_getAPI()?.pointee.setEnabled(true)
    }
}
#endif

@_spi(Private) extension SentryCrashWrapper {
    @objc
    public func startBinaryImageCache() {
        sentrycrashbic_startCache()
    }
    
    @objc
    public func stopBinaryImageCache() {
        sentrycrashbic_stopCache()
    }
    
    @objc
    public var crashedLastLaunch: Bool {
        return bridge.crashReporter.crashedLastLaunch
    }
    
    @objc
    public var durationFromCrashStateInitToLastCrash: TimeInterval {
        return sentrycrashstate_currentState()?.pointee.durationFromCrashStateInitToLastCrash ?? 0
    }
    
    @objc
    public var activeDurationSinceLastCrash: TimeInterval {
        return bridge.crashReporter.activeDurationSinceLastCrash
    }
    
    @objc
    public var isBeingTraced: Bool {
        return sentrycrashdebug_isBeingTraced()
    }
    
    @objc
    public var isSimulatorBuild: Bool {
        return sentrycrash_isSimulatorBuild()
    }
    
    @objc
    public var isApplicationInForeground: Bool {
        return sentrycrashstate_currentState()?.pointee.applicationIsInForeground ?? false
    }
    
    @objc
    public var freeMemorySize: UInt64 {
        return sentrycrashcm_system_freememory_size()
    }
    
    @objc
    public var appMemorySize: UInt64 {
        var info = task_vm_info_data_t()
        var size = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<natural_t>.stride)
        let kerr = withUnsafeMutablePointer(to: &info) { infoPtr in
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), 
                     UnsafeMutableRawPointer(infoPtr).assumingMemoryBound(to: integer_t.self), &size)
        }
        
        if kerr == KERN_SUCCESS {
            return info.internal + info.compressed
        }
        
        return 0
    }
    
    @objc
    public func enrichScope(_ scope: Scope) {
        let systemInfo = self.systemInfo
        
        enrichScopeWithOSData(scope, systemInfo: systemInfo)
        
        // SystemInfo should only be nil when SentryCrash has not been installed
        if systemInfo.isEmpty {
            return
        }
        
        enrichScopeWithDeviceData(scope, systemInfo: systemInfo)
        enrichScopeWithAppData(scope, systemInfo: systemInfo)
        enrichScopeWithRuntimeData(scope)
    }
    
    // MARK: - Private Methods
    
    private func enrichScopeWithOSData(_ scope: Scope, systemInfo: [String: Any]) {
        var osData: [String: Any] = [:]
        
        osData["name"] = getOSName()
        osData["version"] = getOSVersion()
        
        // SystemInfo should only be nil when SentryCrash has not been installed
        if !systemInfo.isEmpty {
            osData["build"] = systemInfo["osVersion"]
            osData["kernel_version"] = systemInfo["kernelVersion"]
            osData["rooted"] = systemInfo["isJailbroken"]
        }
        
        scope.setContext(value: osData, key: "os")
    }
    
    private func enrichScopeWithDeviceData(_ scope: Scope, systemInfo: [String: Any]) {
        var deviceData: [String: Any] = [:]
        
        deviceData["simulator"] = isSimulator()
        
        if let systemName = systemInfo["systemName"] as? String {
            deviceData["family"] = getDeviceFamily(from: systemName)
        }
        
        deviceData["arch"] = systemInfo["cpuArchitecture"]
        deviceData["model"] = systemInfo["machine"]
        deviceData["model_id"] = systemInfo["model"]
        deviceData["free_memory"] = systemInfo["freeMemorySize"]
        deviceData["usable_memory"] = systemInfo["usableMemorySize"]
        deviceData["memory_size"] = systemInfo["memorySize"]
        
        deviceData["locale"] = Locale.autoupdatingCurrent.identifier
        
        // Only include these boolean flags when they are `true` to reduce payload size.
        // These flags are `false` for the vast majority of events (regular iOS apps, native macOS apps, etc.),
        // so omitting them when `false` significantly reduces the payload size without losing meaningful information.
        if #available(macOS 12, *) {
            if self.processInfoWrapper.isiOSAppOnMac {
                deviceData["ios_app_on_macos"] = true
            }
            if self.processInfoWrapper.isMacCatalystApp {
                deviceData["mac_catalyst_app"] = true
            }
        }
        if self.processInfoWrapper.isiOSAppOnVisionOS {
            deviceData["ios_app_on_visionos"] = true
        }
        
        // Set screen dimensions if available
        setScreenDimensions(&deviceData)
        
        scope.setContext(value: deviceData, key: "device")
    }
    
    private func enrichScopeWithAppData(_ scope: Scope, systemInfo: [String: Any]) {
        var appData: [String: Any] = [:]
        let infoDict = Bundle.main.infoDictionary ?? [:]
        
        appData["app_identifier"] = infoDict["CFBundleIdentifier"]
        appData["app_name"] = infoDict["CFBundleName"]
        appData["app_build"] = infoDict["CFBundleVersion"]
        appData["app_version"] = infoDict["CFBundleShortVersionString"]
        
        appData["app_start_time"] = systemInfo["appStartTime"]
        appData["device_app_hash"] = systemInfo["deviceAppHash"]
        appData["app_id"] = systemInfo["appID"]
        appData["build_type"] = systemInfo["buildType"]
        
        scope.setContext(value: appData, key: "app")
    }
    
    private func enrichScopeWithRuntimeData(_ scope: Scope) {
        var runtimeContext: [String: Any] = [:]

        if #available(macOS 12, *) {
            // We set this info on the runtime context because the app context has no existing fields
            // suitable for representing Catalyst or iOS-on-Mac execution modes. We also wanted to avoid
            // adding two new Apple-specific fields to the app context. Coming up with a generic,
            // reusable property on the app context proved difficult, so instead we reuse the "name"
            // field of the runtime context as a pragmatic and semantically acceptable solution.
            // isiOSAppOnMac and isMacCatalystApp are mutually exclusive, so we only set one of them.
            if self.processInfoWrapper.isiOSAppOnMac {
                runtimeContext["name"] = "iOS App on Mac"
                runtimeContext["raw_description"] = "ios-app-on-mac"
            }

            if self.processInfoWrapper.isMacCatalystApp {
                runtimeContext["name"] = "Mac Catalyst App"
                runtimeContext["raw_description"] = "mac-catalyst-app"
            }
        }

        if !runtimeContext.isEmpty {
            scope.setContext(value: runtimeContext, key: "runtime")
        }
    }
    
    private func getOSName() -> String? {
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
    
    private func getOSVersion() -> String {
        // For MacCatalyst the UIDevice returns the current version of MacCatalyst and not the
        // macOSVersion. Therefore we have to use NSProcessInfo.
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK && !targetEnvironment(macCatalyst)
        return Dependencies.uiDeviceWrapper.getSystemVersion()
#else
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK && !targetEnvironment(macCatalyst)
    }
    
    private func isSimulator() -> Bool {
#if targetEnvironment(simulator)
        return true
#else
        return false
#endif // targetEnvironment(simulator)
    }
    
    private func getDeviceFamily(from systemName: String) -> String? {
        let family = systemName.components(separatedBy: .whitespacesAndNewlines).first
#if targetEnvironment(macCatalyst)
        // This would be iOS. Set it to macOS instead.
        return "macOS"
#else
        return family
#endif // targetEnvironment(macCatalyst)
    }
    
    private func setScreenDimensions(_ deviceData: inout [String: Any]) {
        // The UIWindowScene is unavailable on visionOS
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        let screenSize = bridge.activeScreenSize()
        if screenSize != CGSize.zero {
            deviceData["screen_height_pixels"] = screenSize.height
            deviceData["screen_width_pixels"] = screenSize.width
        }
#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    }
}
// swiftlint:enable missing_docs
