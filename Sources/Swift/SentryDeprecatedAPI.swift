internal import _SentryPrivate
import Foundation

extension SentryError {
    /// Domain for errors created by the SDK.
    public static var domain: String {
        "SentryErrorDomain"
    }

    /// An `NSError` in `SentryError.domain` with this case as its code.
    ///
    /// - Parameter description: Localized description stored on the error.
    public func nsError(description: String) -> NSError {
        NSError(
            domain: Self.domain,
            code: rawValue,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }

    /// An `NSError` in `SentryError.domain` that wraps another error.
    ///
    /// - Parameters:
    ///   - description: Localized description stored on the error.
    ///   - underlyingError: Error stored under `NSUnderlyingErrorKey`.
    public func nsError(description: String, underlyingError: NSError) -> NSError {
        NSError(
            domain: Self.domain,
            code: rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: description,
                NSUnderlyingErrorKey: underlyingError
            ]
        )
    }

    /// An `NSError` in `SentryError.domain` whose description includes an exception reason.
    ///
    /// - Parameters:
    ///   - description: Text placed before the exception reason.
    ///   - exception: Exception whose reason is appended to the description.
    public func nsError(description: String, exception: NSException) -> NSError {
        let reason = exception.reason ?? "null"
        return nsError(description: "\(description) (\(reason))")
    }

    /// An `NSError` in `SentryError.domain` whose description includes a kernel return code.
    ///
    /// - Parameters:
    ///   - description: Text placed before the kernel description.
    ///   - kernelErrorCode: Mach `kern_return_t` value.
    public func nsError(description: String, kernelErrorCode: Int32) -> NSError {
        let kernelDescription = SentryKernelErrorDescription.string(
            forKernelReturnCode: kernelErrorCode)
        return nsError(description: "\(description) (\(kernelDescription))")
    }
}

extension SentrySpanStatus {
    /// Wire value for this status, such as `ok` or `deadline_exceeded`.
    public var name: String {
        switch self {
        case .undefined:
            return "undefined"
        case .ok:
            return "ok"
        case .deadlineExceeded:
            return "deadline_exceeded"
        case .unauthenticated:
            return "unauthenticated"
        case .permissionDenied:
            return "permission_denied"
        case .notFound:
            return "not_found"
        case .resourceExhausted:
            return "resource_exhausted"
        case .invalidArgument:
            return "invalid_argument"
        case .unimplemented:
            return "unimplemented"
        case .unavailable:
            return "unavailable"
        case .internalError:
            return "internal_error"
        case .unknownError:
            return "unknown_error"
        case .cancelled:
            return "cancelled"
        case .alreadyExists:
            return "already_exists"
        case .failedPrecondition:
            return "failed_precondition"
        case .aborted:
            return "aborted"
        case .outOfRange:
            return "out_of_range"
        case .dataLoss:
            return "data_loss"
        @unknown default:
            return "undefined"
        }
    }
}

extension Baggage {
    /// HTTP header field that carries baggage.
    public static let httpHeaderField = "baggage"
}

extension TraceHeader {
    /// HTTP header field that carries a sentry trace header.
    public static let httpHeaderField = "sentry-trace"
}
