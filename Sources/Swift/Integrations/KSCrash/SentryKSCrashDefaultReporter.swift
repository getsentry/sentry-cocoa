// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Darwin
import Foundation
import KSCrashRecording

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

/**
 * A `SentryCrashReporter` implementation that sources data from `KSCrash.shared`
 * instead of the legacy SentryCrash C APIs.
 *
 * Key differences from `SentryDefaultCrashReporter`:
 * - System info comes from `KSCrash.shared.systemInfo` (keys: `freeMemory`, `usableMemory`
 *   instead of the SentryCrash fork keys `freeMemorySize`, `usableMemorySize`).
 * - Binary image cache is managed automatically by KSCrash; start/stop are no-ops.
 * - `durationFromCrashStateInitToLastCrash` is not tracked by KSCrash; returns 0.
 */
@objc @_spi(Private)
public final class SentryKSCrashDefaultReporter: NSObject, SentryCrashReporter {

    public let processInfoWrapper: SentryProcessInfoSource

    @objc
    public let systemInfo: [String: Any]

    @objc
    public init(processInfoWrapper: SentryProcessInfoSource) {
        self.processInfoWrapper = processInfoWrapper
        self.systemInfo = KSCrash.shared.systemInfo
        super.init()
    }

#if SENTRY_TEST || SENTRY_TEST_CI
    /// Inject system info during tests.
    public init(processInfoWrapper: SentryProcessInfoSource, systemInfo: [String: Any]) {
        self.processInfoWrapper = processInfoWrapper
        self.systemInfo = systemInfo
        super.init()
    }
#endif // SENTRY_TEST || SENTRY_TEST_CI
}

@_spi(Private) extension SentryKSCrashDefaultReporter {

    // MARK: - SentryCrashReporter

    @objc
    public func startBinaryImageCache() {
        // TODO: eventually, we'd upstream changes to KSCrash and rely on their bic
        sentrycrashbic_startCache()
    }

    @objc
    public func stopBinaryImageCache() {
        // TODO: eventually, we'd upstream changes to KSCrash and rely on their bic
        sentrycrashbic_stopCache()
    }

    @objc
    public var crashedLastLaunch: Bool {
        KSCrash.shared.crashedLastLaunch
    }

    /// KSCrash does not track time-from-crash-state-init; returns 0.
    @objc
    public var durationFromCrashStateInitToLastCrash: TimeInterval {
        0
    }

    @objc
    public var activeDurationSinceLastCrash: TimeInterval {
        KSCrash.shared.activeDurationSinceLastCrash
    }

    @objc
    public var isBeingTraced: Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let result = sysctl(&mib, 4, &info, &size, nil, 0)
        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    @objc
    public var isSimulatorBuild: Bool {
#if targetEnvironment(simulator)
        return true
#else
        return false
#endif // targetEnvironment(simulator)
    }

    @objc
    public var isApplicationInForeground: Bool {
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        if Thread.isMainThread {
            return UIApplication.shared.applicationState != .background
        }
        var inForeground = false
        DispatchQueue.main.sync {
            inForeground = UIApplication.shared.applicationState != .background
        }
        return inForeground
#else
        // macOS / watchOS: no backgrounding concept at the UIApplication level.
        return true
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    }

    @objc
    public var freeMemorySize: UInt64 {
        systemInfo["freeMemory"] as? UInt64 ?? 0
    }

    @objc
    public var appMemorySize: UInt64 {
        var info = task_vm_info_data_t()
        var size = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<natural_t>.stride
        )
        let kerr = withUnsafeMutablePointer(to: &info) { infoPtr in
            task_info(
                mach_task_self_,
                task_flavor_t(TASK_VM_INFO),
                UnsafeMutableRawPointer(infoPtr).assumingMemoryBound(to: integer_t.self),
                &size
            )
        }
        guard kerr == KERN_SUCCESS else { return 0 }
        return info.internal + info.compressed
    }

    @objc
    public func enrichScope(_ scope: Scope) {
        let info = systemInfo

        enrichScopeWithOSData(scope, systemInfo: info)

        // systemInfo is empty when KSCrash has not been installed yet.
        if info.isEmpty {
            return
        }

        enrichScopeWithDeviceData(scope, systemInfo: info)
        enrichScopeWithAppData(scope, systemInfo: info)
        enrichScopeWithRuntimeData(scope)
    }

    // MARK: - Private helpers

    private func enrichScopeWithOSData(_ scope: Scope, systemInfo: [String: Any]) {
        var osData: [String: Any] = [:]

        osData["name"] = getOSName()
        osData["version"] = getOSVersion()

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

        // KSCrash uses "freeMemory" / "usableMemory" (vs SentryCrash's "freeMemorySize" / "usableMemorySize")
        deviceData["free_memory"] = systemInfo["freeMemory"]
        deviceData["usable_memory"] = systemInfo["usableMemory"]
        deviceData["memory_size"] = systemInfo["memorySize"]

        deviceData["locale"] = Locale.autoupdatingCurrent.identifier

        // Only include these boolean flags when true to reduce payload size.
        if #available(macOS 12, *) {
            if processInfoWrapper.isiOSAppOnMac {
                deviceData["ios_app_on_macos"] = true
            }
            if processInfoWrapper.isMacCatalystApp {
                deviceData["mac_catalyst_app"] = true
            }
        }
        if processInfoWrapper.isiOSAppOnVisionOS {
            deviceData["ios_app_on_visionos"] = true
        }

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
            if processInfoWrapper.isiOSAppOnMac {
                runtimeContext["name"] = "iOS App on Mac"
                runtimeContext["raw_description"] = "ios-app-on-mac"
            }
            if processInfoWrapper.isMacCatalystApp {
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
        return "macOS"
#else
        return family
#endif // targetEnvironment(macCatalyst)
    }

    private func setScreenDimensions(_ deviceData: inout [String: Any]) {
        // The UIWindowScene is unavailable on visionOS
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        let screenSize = SentryDependencyContainerSwiftHelper.activeScreenSize()
        if screenSize != CGSize.zero {
            deviceData["screen_height_pixels"] = screenSize.height
            deviceData["screen_width_pixels"] = screenSize.width
        }
#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    }
}
// swiftlint:enable missing_docs
