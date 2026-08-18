@_spi(Private) @testable import Sentry
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
}
