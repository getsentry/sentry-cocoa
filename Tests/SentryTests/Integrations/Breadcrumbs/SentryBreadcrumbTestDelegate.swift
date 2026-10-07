#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import SentryTestUtils

class SentryBreadcrumbTestDelegate: NSObject, SentryBreadcrumbDelegate {
    
    var addCrumbInvocations = Invocations<Breadcrumb>()
    func add(_ crumb: Breadcrumb) {
        print("crumb: \(crumb)")
        addCrumbInvocations.record(crumb)
    }
}
