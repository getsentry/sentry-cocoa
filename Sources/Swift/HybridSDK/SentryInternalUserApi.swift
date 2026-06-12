// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

@_spi(Private) public final class SentryInternalUserApi {

    /// Creates a `User` from a dictionary representation.
    public func fromDictionary(_ dictionary: [String: Any]) -> User {
        PrivateSentrySDKOnly.user(with: dictionary)
    }
}
// swiftlint:enable missing_docs
