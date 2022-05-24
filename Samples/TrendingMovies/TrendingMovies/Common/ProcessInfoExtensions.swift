import Foundation

extension ProcessInfo {
    static var isBenchmarking = ProcessInfo().arguments.contains("--io.sentry.ui-test.benchmarking")
}
