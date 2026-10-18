import Darwin
import Foundation

/// Returns `true` if the process has a debugger attached.
/// - SeeAlso: https://developer.apple.com/library/archive/qa/qa1361/_index.html
public func isDebugging() -> Bool {
    var processInfo = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

    // Initialize the flags so that, if sysctl fails, we get a predictable result.
    processInfo.kp_proc.p_flag = 0

    guard sysctl(&mib, u_int(mib.count), &processInfo, &size, nil, 0) == 0 else {
        print("sysctl failed while trying to get kinfo_proc")
        return false
    }

    return (processInfo.kp_proc.p_flag & P_TRACED) != 0
}

/// Returns `true` if the process is running in a simulator.
/// - SeeAlso: https://stackoverflow.com/a/45329149
public func isSimulator() -> Bool {
    ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
}
