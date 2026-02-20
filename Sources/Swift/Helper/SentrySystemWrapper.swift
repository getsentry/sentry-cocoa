// swiftlint:disable missing_docs
import Foundation

#if os(iOS) || os(macOS)

import Darwin

/// A wrapper around low-level system APIs that are found in headers such as `<sys/...>` and
/// `<mach/...>`.
@objc(SentrySystemWrapper)
@_spi(Private) open class SentrySystemWrapper: NSObject {

    private let processorCount: Float

    @objc
    public init(processorCount: Int) {
        self.processorCount = Float(processorCount)
        super.init()
    }

    @objc
    open func memoryFootprintBytes(_ error: NSErrorPointer) -> mach_vm_size_t {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<natural_t>.stride)

        let status = withUnsafeMutablePointer(to: &info) { infoPtr in
            task_info(
                mach_task_self_,
                task_flavor_t(TASK_VM_INFO),
                UnsafeMutableRawPointer(infoPtr).assumingMemoryBound(to: integer_t.self),
                &count)
        }

        if status != KERN_SUCCESS {
            if let error = error {
                error.pointee = nsErrorFromKernelError("task_info reported an error.", status)
            }
            return 0
        }

        if count >= swiftTaskVMInfoRev1Count() {
            return info.phys_footprint
        }
        return info.resident_size
    }

    /// The CPU usage per core, where the order of results corresponds to the core number as
    /// returned by the underlying system call.
    @objc(cpuUsageWithError:)
    open func cpuUsage() throws -> NSNumber {
        var list: thread_act_array_t?
        var count: mach_msg_type_number_t = 0

        let taskThreadsStatus = task_threads(mach_task_self_, &list, &count)
        guard taskThreadsStatus == KERN_SUCCESS, let list = list else {
            if taskThreadsStatus != KERN_SUCCESS {
                throw nsErrorFromKernelError("task_threads reported an error.", taskThreadsStatus)
            }
            throw NSError(domain: SentryErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "task_threads returned nil"])
        }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: list)),
                vm_size_t(MemoryLayout<thread_t>.size) * vm_size_t(count))
        }

        var usage: Float = 0
        let threadBasicInfoCount = mach_msg_type_number_t(MemoryLayout<thread_basic_info_data_t>.stride / MemoryLayout<natural_t>.stride)
        for i in 0..<Int(count) {
            let thread = list[i]
            var threadInfo = thread_basic_info_data_t()
            var infoSize = threadBasicInfoCount

            let threadInfoStatus = withUnsafeMutablePointer(to: &threadInfo) { infoPtr in
                thread_info(
                    thread,
                    thread_flavor_t(THREAD_BASIC_INFO),
                    UnsafeMutableRawPointer(infoPtr).assumingMemoryBound(to: integer_t.self),
                    &infoSize)
            }

            if threadInfoStatus != KERN_SUCCESS {
                throw nsErrorFromKernelError("task_threads reported an error.", threadInfoStatus)
            }

            usage += Float(threadInfo.cpu_usage) / processorCount
        }

        return NSNumber(value: usage)
    }

#if arch(arm64) || arch(arm)
    /// The cumulative amount of nanojoules expended by the CPU for this task since process start.
    @objc(cpuEnergyUsageWithError:)
    open func cpuEnergyUsage() throws -> NSNumber {
        var powerInfo = task_power_info_v2()
        var size = mach_msg_type_number_t(MemoryLayout<task_power_info_v2>.stride / MemoryLayout<natural_t>.stride)

        let kr = withUnsafeMutablePointer(to: &powerInfo) { infoPtr in
            task_info(
                mach_task_self_,
                task_flavor_t(TASK_POWER_INFO_V2),
                UnsafeMutableRawPointer(infoPtr).assumingMemoryBound(to: integer_t.self),
                &size)
        }

        if kr != KERN_SUCCESS {
            throw nsErrorFromKernelError("Error with task_info(…TASK_POWER_INFO_V2…).", kr)
        }

        return NSNumber(value: powerInfo.task_energy)
    }
#endif

}

/// Returns TASK_VM_INFO_REV1_COUNT. The macro is unavailable in Swift; REV1 = full count - (rev2..rev7 deltas) = -55.
private func swiftTaskVMInfoRev1Count() -> mach_msg_type_number_t {
    mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<natural_t>.stride) - 55
}

private func nsErrorFromKernelError(_ description: String, _ kr: kern_return_t) -> NSError {
    let krDescription: String
    if let cStr = mach_error_string(kr) {
        krDescription = String(cString: cStr)
    } else {
        krDescription = "Unknown error (code: \(kr))"
    }
    return NSError(
        domain: SentryErrorDomain,
        code: Int(SentryError.kernel.rawValue),
        userInfo: [NSLocalizedDescriptionKey: "\(description) (\(krDescription))"])
}

#endif // os(iOS) || os(macOS)
