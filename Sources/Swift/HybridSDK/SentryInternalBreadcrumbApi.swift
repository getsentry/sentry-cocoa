// swiftlint:disable missing_docs
import Foundation

/// Provides breadcrumb creation from dictionary representation.
public struct SentryInternalBreadcrumbApi {

    typealias Dependencies = BreadcrumbDeserializerProvider

    private let deserializer: BreadcrumbDeserializer

    init(dependencies: Dependencies) {
        self.deserializer = dependencies.breadcrumbDeserializer
    }

    /// Creates a `Breadcrumb` from a dictionary representation.
    public func fromDictionary(_ dictionary: [String: Any]) -> Breadcrumb {
        deserializer.breadcrumb(from: dictionary)
    }
}
// swiftlint:enable missing_docs
