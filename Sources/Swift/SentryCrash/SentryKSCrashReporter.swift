// swiftlint:disable missing_docs
#if ENABLE_KSCRASH
internal import _SentryPrivate
import Darwin
import Foundation
import KSCrashRecording
import MachO

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

@_spi(Private)
@objc public final class SentryKSCrashReporter: NSObject, SentryCrashReporter {

    @objc public let processInfoWrapper: SentryProcessInfoSource
    @objc public let systemInfo: [String: Any]

    @objc public init(processInfoWrapper: SentryProcessInfoSource = Dependencies.processInfoWrapper) {
        self.processInfoWrapper = processInfoWrapper
        self.systemInfo = (KSCrash.shared.systemInfo as NSDictionary) as? [String: Any] ?? [:]
        super.init()
    }

    @objc public var crashedLastLaunch: Bool {
        KSCrash.shared.crashedLastLaunch
    }

    @objc public var durationFromCrashStateInitToLastCrash: TimeInterval {
        // No direct KSCrash equivalent for crash-state-init-to-last-crash duration.
        return 0
    }

    @objc public var activeDurationSinceLastCrash: TimeInterval {
        KSCrash.shared.activeDurationSinceLastCrash
    }

    @objc public var isBeingTraced: Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    @objc public var isSimulatorBuild: Bool {
#if targetEnvironment(simulator)
        return true
#else
        return false
#endif
    }

    @objc public var isApplicationInForeground: Bool {
        let state = AppStateTracker.shared.transitionState
        return state == .active || state == .foregrounding || state == .deactivating
    }

    @objc public var freeMemorySize: UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(stats.free_count) * UInt64(vm_page_size)
    }

    @objc public var appMemorySize: UInt64 {
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

    @objc public func startBinaryImageCache() {
        sentrycrashbic_startCache()
    }

    @objc public func stopBinaryImageCache() {
        sentrycrashbic_stopCache()
    }

    @objc public func enrichScope(_ scope: Scope) {
        let systemInfo = self.systemInfo

        enrichScopeWithOSData(scope, systemInfo: systemInfo)

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

    #if !SDK_V10
        deviceData["locale"] = Locale.autoupdatingCurrent.identifier
    #endif

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
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK && !targetEnvironment(macCatalyst)
        return Dependencies.uiDeviceWrapper.getSystemVersion()
#else
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
#endif
    }

    private func isSimulator() -> Bool {
#if targetEnvironment(simulator)
        return true
#else
        return false
#endif
    }

    private func getDeviceFamily(from systemName: String) -> String? {
        let family = systemName.components(separatedBy: .whitespacesAndNewlines).first
#if targetEnvironment(macCatalyst)
        return "macOS"
#else
        return family
#endif
    }

    private func setScreenDimensions(_ deviceData: inout [String: Any]) {
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        // Screen size not available from KSCrash APIs; skip
#endif
    }
}
#endif // ENABLE_KSCRASH
// swiftlint:enable missing_docs
