import Darwin
import Foundation

extension CrashE2ERuntime {
    /// A stable frame for the live runner test to find in symbolicated timeout diagnostics.
    /// There is deliberately no app-side deadline: ordinary runner cleanup must stop us.
    @inline(never)
    static func crashE2EHarnessTimeoutWait() -> Never {
        let semaphore = DispatchSemaphore(value: 0)
        NSLog("CrashE2E - harness-timeout ready; waiting in crashE2EHarnessTimeoutWait (pid: \(getpid())) ready-at: \(Date().timeIntervalSince1970)")
        while true {
            semaphore.wait()
        }
    }
}
