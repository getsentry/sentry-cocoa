import Foundation

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class TestSentryViewHierarchy: SentryViewHierarchy {

    var result: Data = Data()

    override func fetch() -> Data {
        return result
    }
}
#endif
