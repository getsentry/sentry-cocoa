// swiftlint:disable missing_docs
#if !(os(watchOS) || os(tvOS) || os(visionOS))
import Foundation

public typealias SentryRAMBytes = mach_vm_size_t

private let sentryErrorKernelCode = 109

@_spi(Private) @objc
open class SentrySystemWrapper: NSObject {

    private let processorCount: Float

    @objc
    public init(processorCount: Int) {
        self.processorCount = Float(processorCount)
    }

    @objc
    open func memoryFootprintBytes() throws -> NSNumber {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)

        let status = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rawPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rawPtr, &count)
            }
        }

        guard status == KERN_SUCCESS else {
            throw NSError(domain: SentryErrorDomain, code: sentryErrorKernelCode,
                          userInfo: [NSLocalizedDescriptionKey: "task_info reported an error: \(status)"])
        }

        return NSNumber(value: info.phys_footprint)
    }

    @objc
    public func normalizeCPUUsage(_ rawUsage: Float) -> Float {
#if SDK_V10
        return (rawUsage / Float(TH_USAGE_SCALE)) * 100.0 / processorCount
#else
        return rawUsage / processorCount
#endif
    }

    @objc
    open func cpuUsage() throws -> NSNumber {
        var count: mach_msg_type_number_t = 0
        var list: thread_act_array_t?

        let taskThreadsStatus = task_threads(mach_task_self_, &list, &count)
        guard taskThreadsStatus == KERN_SUCCESS else {
            throw NSError(domain: SentryErrorDomain, code: sentryErrorKernelCode,
                          userInfo: [NSLocalizedDescriptionKey: "task_threads reported an error: \(taskThreadsStatus)"])
        }

        guard let threadList = list else {
            throw NSError(domain: SentryErrorDomain, code: sentryErrorKernelCode,
                          userInfo: [NSLocalizedDescriptionKey: "task_threads returned nil list"])
        }

        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threadList), vm_size_t(MemoryLayout<thread_t>.size) * vm_size_t(count))
        }

        var usage: Float = 0
        for i in 0..<Int(count) {
            let thread = threadList[i]

            var infoSize = mach_msg_type_number_t(MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<natural_t>.size)
            var data = thread_basic_info_data_t()
            let threadInfoStatus = withUnsafeMutablePointer(to: &data) { dataPtr in
                dataPtr.withMemoryRebound(to: integer_t.self, capacity: Int(infoSize)) { rawPtr in
                    thread_info(thread, thread_flavor_t(THREAD_BASIC_INFO), rawPtr, &infoSize)
                }
            }

            guard threadInfoStatus == KERN_SUCCESS else {
                throw NSError(domain: SentryErrorDomain, code: sentryErrorKernelCode,
                              userInfo: [NSLocalizedDescriptionKey: "thread_info reported an error: \(threadInfoStatus)"])
            }

            usage += Float(data.cpu_usage)
        }

        return NSNumber(value: normalizeCPUUsage(usage))
    }

#if arch(arm) || arch(arm64)
    @objc
    open func cpuEnergyUsage() throws -> NSNumber {
        var powerInfo = task_power_info_v2()
        var size = mach_msg_type_number_t(MemoryLayout<task_power_info_v2>.size / MemoryLayout<natural_t>.size)

        let kr = withUnsafeMutablePointer(to: &powerInfo) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { rawPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_POWER_INFO_V2), rawPtr, &size)
            }
        }

        guard kr == KERN_SUCCESS else {
            throw NSError(domain: SentryErrorDomain, code: sentryErrorKernelCode,
                          userInfo: [NSLocalizedDescriptionKey: "Error with task_info(…TASK_POWER_INFO_V2…): \(kr)"])
        }

        return NSNumber(value: powerInfo.task_energy)
    }
#endif
}

#endif // !(os(watchOS) || os(tvOS) || os(visionOS))
// swiftlint:enable missing_docs
