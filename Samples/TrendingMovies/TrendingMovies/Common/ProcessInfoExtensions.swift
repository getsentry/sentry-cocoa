import Foundation

extension ProcessInfo {
    static var isBenchmarking = ProcessInfo().arguments.contains("--io.sentry.ui-test.benchmarking")
    static var disableProfiling = ProcessInfo().arguments.contains("--io.sentry.disable-profiling")
}
