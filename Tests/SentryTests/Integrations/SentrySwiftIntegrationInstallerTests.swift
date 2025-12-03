@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentrySwiftIntegrationInstallerTests: XCTestCase {

    private var testHub: TestHub!
    private var options: Options!
    private var logOutput: TestLogOutput!

    override func setUp() {
        super.setUp()

        // Create test hub
        testHub = TestHub(client: nil, andScope: nil)
        SentrySDKInternal.setCurrentHub(testHub)

        // Create options
        options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentrySwiftIntegrationInstallerTests")
        options.debug = true

        // Setup log output
        logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)
    }

    override func tearDown() {
        clearTestState()

        super.tearDown()
    }
    
    // We are not testing `SwiftAsyncIntegration`, but use it as an example for an installed integration
    func testInstall_IntegrationNamesMatchExpectedValues() {
        // Arrange
        options.swiftAsyncStacktraces = true

        // Act
        SentrySwiftIntegrationInstaller.install(with: options)

        // Assert
        // Verify the integration name matches what's defined in SwiftAsyncIntegration
        if testHub.installedIntegrationNames().contains("SentrySwiftAsyncIntegration") {
            XCTAssertEqual(SwiftAsyncIntegration<SentryDependencyContainer>.name, "SentrySwiftAsyncIntegration",
                          "Integration name should match the static name property")
        }
    }

    func testInstall_LogsInstalledIntegrations() {
        // Arrange
        options.swiftAsyncStacktraces = true

        // Act
        SentrySwiftIntegrationInstaller.install(with: options)

        // Assert
        let logs = logOutput.loggedMessages.joined()
        XCTAssertTrue(logs.contains("Integration installed: SentrySwiftAsyncIntegration"),
                     "Should log when SwiftAsyncIntegration is installed")
    }

    func testInstall_WithDisabledIntegration_DoesNotLogInstallation() {
        // Arrange
        options.swiftAsyncStacktraces = false

        // Act
        SentrySwiftIntegrationInstaller.install(with: options)

        // Assert
        let logs = logOutput.loggedMessages.joined()
        XCTAssertFalse(logs.contains("Integration installed: SentrySwiftAsyncIntegration"),
                      "Should not log when SwiftAsyncIntegration is not installed")
    }
}
