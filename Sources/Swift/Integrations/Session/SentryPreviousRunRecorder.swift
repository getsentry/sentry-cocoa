import Foundation

/// Records how the previous run of the app ended.
///
/// MetricKit can deliver the diagnostic of a run on a later launch. Recording which runs ended
/// fatally, and how the SDK reported them, lets the SDK match such a diagnostic to the run. See
/// decision 41 in `develop-docs/DECISIONS.md`.
protocol SentryPreviousRunRecorder: AnyObject {
    /// - Parameters:
    ///   - crashed: Whether the crash handler recorded a crash report for the previous run.
    ///   - watchdogTerminated: Whether the SDK detected a watchdog termination of the previous run.
    func recordPreviousRun(crashed: Bool, watchdogTerminated: Bool)
}
