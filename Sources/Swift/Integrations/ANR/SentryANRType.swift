@objc
public enum SentryANRType: Int {
    case fullyBlocking
    case nonFullyBlocking
    case unknown
}

@objc
public class SentryAppHangTypeMapper: NSObject {

    private enum ExceptionType: String {
        case fullyBlocking = "App Hanging Fully Blocked"
        case nonFullyBlocking = "App Hanging Non Fully Blocked"
        case unknown = "App Hanging"
    }

    @objc
    public static func getExceptionType(anrType: SentryANRType) -> String {
        switch anrType {
        case .fullyBlocking:
            return ExceptionType.fullyBlocking.rawValue
        case .nonFullyBlocking:
            return ExceptionType.nonFullyBlocking.rawValue
        default:
            return ExceptionType.unknown.rawValue
        }
    }

    @objc
    public static func isExceptionTypeAppHang(exceptionType: String) -> Bool {
        return ExceptionType(rawValue: exceptionType) != nil
    }
}
