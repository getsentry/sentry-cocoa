@testable import Sentry
import SentryTestUtils

// Note: This file should ideally live in SentryTestUtils, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtils.

class TestSentryWatchdogTerminationBreadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor {
    var addSerializedBreadcrumbInvocations = Invocations<[AnyHashable: Any]>()
    var clearBreadcrumbsInvocations = Invocations<Void>()
    var clearInvocations = Invocations<Void>()

    override func addSerializedBreadcrumb(_ crumb: [AnyHashable: Any]) {
        addSerializedBreadcrumbInvocations.record(crumb)
    }

    override func clearBreadcrumbs() {
        clearBreadcrumbsInvocations.record(())
    }

    override func clear() {
        clearInvocations.record(())
    }
}
