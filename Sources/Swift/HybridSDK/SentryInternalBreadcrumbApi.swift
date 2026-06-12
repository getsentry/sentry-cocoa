// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

@_spi(Private) public final class SentryInternalBreadcrumbApi {

    /// Creates a `Breadcrumb` from a dictionary representation.
    public func fromDictionary(_ dictionary: [String: Any]) -> Breadcrumb {
        PrivateSentrySDKOnly.breadcrumb(with: dictionary)
    }
}
// swiftlint:enable missing_docs
