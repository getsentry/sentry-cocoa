internal import _SentryPrivate
import Darwin
import Foundation

protocol SentryMemoryMetricsProvider: AnyObject {
    var freeMemorySize: UInt64 { get }
    var appMemorySize: UInt64 { get }
    var usableMemorySize: UInt64 { get }
    var totalMemorySize: UInt64 { get }
}

final class SentryDefaultMemoryMetricsProvider: SentryMemoryMetricsProvider {
    var freeMemorySize: UInt64 {
        guard let (statistics, pageSize) = vmStatistics() else {
            return 0
        }
        return UInt64(pageSize) * UInt64(statistics.free_count)
    }

    var appMemorySize: UInt64 {
        var info = task_vm_info_data_t()
        var size = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<natural_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) { infoPointer in
            task_info(
                mach_task_self_,
                task_flavor_t(TASK_VM_INFO),
                UnsafeMutableRawPointer(infoPointer).assumingMemoryBound(to: integer_t.self),
                &size
            )
        }

        guard result == KERN_SUCCESS else {
            SentrySDKLog.error("Failed to read current app memory: \(String(cString: mach_error_string(result)))")
            return 0
        }
        return UInt64(info.internal + info.compressed)
    }

    var usableMemorySize: UInt64 {
        guard let (statistics, pageSize) = vmStatistics() else {
            return 0
        }
        let usablePages = UInt64(statistics.active_count)
            + UInt64(statistics.inactive_count)
            + UInt64(statistics.wire_count)
            + UInt64(statistics.free_count)
        return UInt64(pageSize) * usablePages
    }

    var totalMemorySize: UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }

    private func vmStatistics() -> (vm_statistics_data_t, vm_size_t)? {
        let hostPort = mach_host_self()
        defer { _ = mach_port_deallocate(mach_task_self_, hostPort) }

        var pageSize: vm_size_t = 0
        var result = host_page_size(hostPort, &pageSize)
        guard result == KERN_SUCCESS else {
            SentrySDKLog.error("Failed to read host page size: \(String(cString: mach_error_string(result)))")
            return nil
        }

        var statistics = vm_statistics_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics_data_t>.stride / MemoryLayout<natural_t>.stride
        )
        result = withUnsafeMutablePointer(to: &statistics) { statisticsPointer in
            host_statistics(
                hostPort,
                HOST_VM_INFO,
                UnsafeMutableRawPointer(statisticsPointer).assumingMemoryBound(to: integer_t.self),
                &count
            )
        }
        guard result == KERN_SUCCESS else {
            SentrySDKLog.error("Failed to read host VM statistics: \(String(cString: mach_error_string(result)))")
            return nil
        }

        return (statistics, pageSize)
    }
}
