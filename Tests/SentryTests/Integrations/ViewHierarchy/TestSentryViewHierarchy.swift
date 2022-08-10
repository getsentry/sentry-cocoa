import Foundation

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class TestSentryViewHierarchy: SentryViewHierarchy {

    var result: [String] = []

    override func fetch() -> [String] {
        return result
    }
}
#endif
