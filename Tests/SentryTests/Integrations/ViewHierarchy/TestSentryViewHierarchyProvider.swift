@_spi(Private) @testable import Sentry

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

class TestSentryViewHierarchyProvider: SentryViewHierarchyProvider {

    var result: Data?
    var appViewHierarchyCallback: (() -> Void)?
    var saveFilePathUsed: String?

    override func appViewHierarchy() -> Data? {
        appViewHierarchyCallback?()
        guard let result = self.result
        else {
            return super.appViewHierarchy()
        }
        return result
    }

    override func saveViewHierarchy(_ filePath: String) -> Bool {
        saveFilePathUsed = filePath
        return true
    }
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
