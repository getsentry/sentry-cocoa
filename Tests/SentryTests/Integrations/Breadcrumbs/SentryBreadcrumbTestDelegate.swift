import Foundation
import SentryTestUtils

class SentryBreadcrumbTestDelegate: NSObject, SentryBreadcrumbDelegate {
    
    var addCrumbInvocations = Invocations<Breadcrumb>()
    func add(_ crumb: Breadcrumb) {
        print("crumb: \(crumb)")
        addCrumbInvocations.record(crumb)
    }
}
