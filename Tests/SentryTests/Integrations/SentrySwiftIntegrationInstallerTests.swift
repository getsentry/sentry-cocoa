@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentrySwiftIntegrationInstallerTests: XCTestCase {

    override func tearDown() {
        SentrySDKInternal.setCurrentHub(nil)

        super.tearDown()
    }
    
    // We are not testing `SwiftAsyncIntegration`, but use it as an example for an installed integration
    func testInstall_AddsInstalledIntegrations() {
        // Arrange
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentrySwiftIntegrationInstallerTests")
        options.debug = true
        options.swiftAsyncStacktraces = true
        
        // Disable other integrations
        options.enableAutoSessionTracking = false
        options.enableAutoPerformanceTracing = false
        options.tracesSampleRate = 0
        options.enableAppHangTracking = false
        options.enableWatchdogTerminationTracking = false
        
        let testHub = TestHub(client: nil, andScope: nil)
        SentrySDKInternal.setCurrentHub(testHub)

        // Act
        SentrySwiftIntegrationInstaller.install(with: options)

        // Assert
        XCTAssertEqual(testHub.installedIntegrationNames().count, 1)
        XCTAssertEqual(try XCTUnwrap(testHub.installedIntegrationNames().first), "SentrySwiftAsyncIntegration")
        XCTAssertEqual(testHub.installedIntegrations().count, 1)
    }

    func testInstall_WithDisabledIntegration_DoesNotAddIntegration() {
        // Arrange
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentrySwiftIntegrationInstallerTests")
        options.debug = true
        options.swiftAsyncStacktraces = false
        
        // Disable other integrations
        options.enableAutoSessionTracking = false
        options.enableAutoPerformanceTracing = false
        options.tracesSampleRate = 0
        options.enableAppHangTracking = false
        options.enableWatchdogTerminationTracking = false
        
        let testHub = TestHub(client: nil, andScope: nil)
        SentrySDKInternal.setCurrentHub(testHub)

        // Act
        SentrySwiftIntegrationInstaller.install(with: options)

        // Assert
        XCTAssertEqual(testHub.installedIntegrationNames().count, 0)
        XCTAssertEqual(testHub.installedIntegrations().count, 0)
    }
}
