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
        let kernelDescription = sentry_kernelErrorDescription(kernelErrorCode)
        return nsError(description: "\(description) (\(kernelDescription))")
    }
}
