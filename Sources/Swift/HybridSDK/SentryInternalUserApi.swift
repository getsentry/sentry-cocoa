// swiftlint:disable missing_docs
import Foundation

/// Provides user creation from dictionary representation.
public struct SentryInternalUserApi {

    typealias Dependencies = UserDeserializerProvider

    private let deserializer: UserDeserializer

    init(dependencies: Dependencies) {
        self.deserializer = dependencies.userDeserializer
    }

    /// Creates a `User` from a dictionary representation.
    public func fromDictionary(_ dictionary: [String: Any]) -> User {
        deserializer.user(from: dictionary)
    }
}
// swiftlint:enable missing_docs
