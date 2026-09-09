@_spi(Private) @testable import Sentry
import Darwin
import XCTest

final class SentryMemoryMetricsProviderTests: XCTestCase {
    func testDefaultProviderReturnsMeaningfulMetrics() {
        let provider = SentryDefaultMemoryMetricsProvider()

        let totalMemorySize = provider.totalMemorySize
        XCTAssertGreaterThan(provider.appMemorySize, 0)
        XCTAssertGreaterThan(provider.usableMemorySize, 0)
        XCTAssertGreaterThan(totalMemorySize, 0)
        XCTAssertLessThanOrEqual(provider.freeMemorySize, totalMemorySize)
    }

    func testMemoryMetrics_whenRead_shouldReleaseHostPort() {
        let provider = SentryDefaultMemoryMetricsProvider()
        let hostPort = mach_host_self()
        defer { _ = mach_port_deallocate(mach_task_self_, hostPort) }

        var referencesBefore = mach_port_urefs_t()
        XCTAssertEqual(
            mach_port_get_refs(mach_task_self_, hostPort, MACH_PORT_RIGHT_SEND, &referencesBefore),
            KERN_SUCCESS
        )

        _ = provider.freeMemorySize
        _ = provider.usableMemorySize

        var referencesAfter = mach_port_urefs_t()
        XCTAssertEqual(
            mach_port_get_refs(mach_task_self_, hostPort, MACH_PORT_RIGHT_SEND, &referencesAfter),
            KERN_SUCCESS
        )
        XCTAssertEqual(referencesAfter, referencesBefore)
    }
}
