@testable import Sentry
import SentryTestUtils

class TestSentryWatchdogTerminationBreadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor {
    var addSerializedBreadcrumbInvocations = Invocations<[AnyHashable: Any]>()
    var clearBroadcrumbsInvocations = Invocations<Void>()
    var clearInvocations = Invocations<Void>()

    override func addSerializedBreadcrumb(_ crumb: [AnyHashable: Any]) {
        addSerializedBreadcrumbInvocations.record(crumb)
    }

    override func clearBreadcrumbs() {
        clearBroadcrumbsInvocations.record(())
    }

    override func clear() {
        clearInvocations.record(())
    }
}
