@_spi(Private) @testable import Sentry

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

class TestSentryViewHierarchyProvider: SentryViewHierarchyProvider {

    var result: Data?
    var appViewHeirarchyCallback: (() -> Void)?
    var saveFilePathUsed: String?

    override func appViewHierarchy() -> Data? {
        appViewHeirarchyCallback?()
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

class TestSentryViewHierarchyProviderHelper: SentryViewHierarchyProviderHelper {
    
    static var viewHierarchyResult: Int32 = 0

    override static func viewHierarchy(from view: UIView!, into context: UnsafeMutablePointer<SentryCrashJSONEncodeContext>!, reportAccessibilityIdentifier: Bool) -> Int32 {
        return viewHierarchyResult != 0 ? viewHierarchyResult : super.viewHierarchy(from: view, into: context, reportAccessibilityIdentifier: reportAccessibilityIdentifier)
    }
}
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
