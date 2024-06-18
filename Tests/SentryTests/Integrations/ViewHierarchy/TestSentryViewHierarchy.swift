#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

class TestSentryViewHierarchy: SentryViewHierarchy {

    var result: Data?
    var viewHierarchyResult: Int32 = 0
    var processViewHierarchyCallback: (() -> Void)?
    var saveFilePathUsed: String?

    override func appViewHierarchy() -> Data? {
        guard let result = self.result
        else {
            return super.appViewHierarchy()
        }
        return result
    }

    override func save(_ filePath: String) -> Bool {
        saveFilePathUsed = filePath
        return true
    }

    override func viewHierarchy(from view: UIView!, into context: UnsafeMutablePointer<SentryCrashJSONEncodeContext>!) -> Int32 {
        return viewHierarchyResult != 0 ? viewHierarchyResult : super.viewHierarchy(from: view, into: context)
    }

    override func processViewHierarchy(_ windows: [UIView]!, add addJSONDataFunc: SentryCrashJSONAddDataFunc!, userData: UnsafeMutableRawPointer!) -> Bool {
        processViewHierarchyCallback?()
        return super .processViewHierarchy(windows, add: addJSONDataFunc, userData: userData)
    }
}
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
