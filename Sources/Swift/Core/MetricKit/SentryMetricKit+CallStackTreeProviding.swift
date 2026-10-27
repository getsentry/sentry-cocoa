#if os(iOS) || os(macOS) || os(visionOS)
import MetricKit

extension SentryMetricKit {
    protocol CallStackTreeProviding {
        var callStackTree: MXCallStackTree { get }
    }
}

extension MXCrashDiagnostic: SentryMetricKit.CallStackTreeProviding { }
extension MXDiskWriteExceptionDiagnostic: SentryMetricKit.CallStackTreeProviding { }
extension MXCPUExceptionDiagnostic: SentryMetricKit.CallStackTreeProviding { }
extension MXHangDiagnostic: SentryMetricKit.CallStackTreeProviding { }
#if os(iOS) || os(visionOS)
@available(iOS 16.0, *)
extension MXAppLaunchDiagnostic: SentryMetricKit.CallStackTreeProviding { }
#endif // os(iOS) || os(visionOS)
#endif // os(iOS) || os(macOS) || os(visionOS)
