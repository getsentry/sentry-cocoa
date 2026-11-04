// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc public enum SentryObjCErrorCode: Int {
    case unknownError = -1
    case invalidDsnError = 100
    case sentryCrashNotInstalledError = 101
    case invalidCrashReportError = 102
    case compressionError = 103
    case jsonConversionError = 104
    case couldNotFindDirectory = 105
    case requestError = 106
    case eventNotSent = 107
    case fileIO = 108
    case kernel = 109
}

@objc(SentryObjCError) public final class SentryObjCError: NSObject {
    private override init() {
        super.init()
    }

    @objc(nsErrorWithCode:description:)
    public static func nsError(code: SentryObjCErrorCode, description: String) -> NSError {
        let error = SentryError(rawValue: code.rawValue) ?? .unknownError
        return error.nsError(description: description)
    }
}

// swiftlint:enable missing_docs
