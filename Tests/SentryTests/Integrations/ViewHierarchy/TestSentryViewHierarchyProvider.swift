#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@_spi(Private) @testable import Sentry
#endif

#if os(iOS) || os(tvOS) || os(visionOS)

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

#endif // os(iOS) || os(tvOS) || os(visionOS)
