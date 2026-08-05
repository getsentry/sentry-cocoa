#if ENABLE_KSCRASH && SENTRY_CRASH_E2E
import Foundation

extension SentryKSCrash {
    /// CrashE2E-only fault injection and synchronization for stored-report delivery.
    ///
    /// `SENTRY_CRASH_E2E` is enabled only when building the CrashE2E test app. Keeping this hook
    /// behind a build condition avoids adding SDK API or production runtime behavior for E2E tests.
    enum CrashE2ETestHook {
        private static let retryableMarkerArgument =
            "--io.sentry.crash-e2e-kscrash-retryable-marker"
        private static let processingCompleteMarkerArgument =
            "--io.sentry.crash-e2e-kscrash-processing-complete"
        private static let errorDomain = "io.sentry.crash-e2e-kscrash"

        static var reportUserInfo: [String: Any]? {
            let marker: String
            switch argumentValue(after: "--scenario") {
            case "kscrash-retry-report-a":
                marker = "crash-e2e-kscrash-report-a"
            case "kscrash-retry-report-b":
                marker = "crash-e2e-kscrash-report-b"
            default:
                return nil
            }
            return [
                "context": [
                    "crash_e2e_kscrash_retry": ["report": marker]
                ]
            ]
        }

        static func retryableProcessingError(for report: [AnyHashable: Any]) -> (any Error)? {
            guard let marker = argumentValue(after: retryableMarkerArgument),
                  contains(marker: marker, in: report) else {
                return nil
            }

            SentrySDKLog.warning(
                "CrashE2E is injecting a retryable KSCrash processing error for marker \(marker)."
            )
            return NSError(
                domain: errorDomain,
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "CrashE2E injected a retryable KSCrash processing error for \(marker)."
                ]
            )
        }

        static func markReportProcessingComplete() {
            guard let path = argumentValue(after: processingCompleteMarkerArgument) else {
                return
            }

            do {
                try Data("complete\n".utf8).write(
                    to: URL(fileURLWithPath: path),
                    options: [.atomic]
                )
            } catch {
                SentrySDKLog.error(
                    "CrashE2E could not write the KSCrash processing marker at \(path): \(error)"
                )
            }
        }

        private static func argumentValue(after argument: String) -> String? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: argument) else {
                return nil
            }
            let valueIndex = arguments.index(after: index)
            guard valueIndex < arguments.endIndex else {
                return nil
            }
            return arguments[valueIndex]
        }

        private static func contains(marker: String, in value: Any) -> Bool {
            if let string = value as? String {
                return string.contains(marker)
            }
            if let dictionary = value as? [AnyHashable: Any] {
                return dictionary.contains { key, value in
                    String(describing: key).contains(marker)
                        || contains(marker: marker, in: value)
                }
            }
            if let array = value as? [Any] {
                return array.contains { contains(marker: marker, in: $0) }
            }
            return false
        }
    }
}
#endif
