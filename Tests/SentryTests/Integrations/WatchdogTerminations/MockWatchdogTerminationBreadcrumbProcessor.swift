@testable import Sentry
import SentryTestUtils

// Note: This file should ideally live in SentryTestUtils, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtils.

class MockWatchdogTerminationBreadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor {
    var addSerializedBreadcrumbInvocations = Invocations<[AnyHashable: Any]>()
    var clearBreadcrumbsInvocations = Invocations<Void>()
    var clearInvocations = Invocations<Void>()
    var flushAndCloseInvocations = Invocations<Void>()

    func addSerializedBreadcrumb(_ crumb: [AnyHashable: Any]) {
        addSerializedBreadcrumbInvocations.record(crumb)
    }

    func clearBreadcrumbs() {
        clearBreadcrumbsInvocations.record(())
    }

    func clear() {
        clearInvocations.record(())
    }

    func flushAndClose() {
        flushAndCloseInvocations.record(())
    }
}
