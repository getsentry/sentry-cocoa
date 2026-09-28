#if os(iOS) || os(macOS) || os(visionOS)
import MetricKit

enum SentryMetricKit {
    protocol CallStackTreeProviding {
        var callStackTree: MXCallStackTree { get }
    }
}

extension MXCrashDiagnostic: SentryMetricKit.CallStackTreeProviding { }
extension MXDiskWriteExceptionDiagnostic: SentryMetricKit.CallStackTreeProviding { }
extension MXCPUExceptionDiagnostic: SentryMetricKit.CallStackTreeProviding { }
extension MXHangDiagnostic: SentryMetricKit.CallStackTreeProviding { }
#endif // os(iOS) || os(macOS) || os(visionOS)
