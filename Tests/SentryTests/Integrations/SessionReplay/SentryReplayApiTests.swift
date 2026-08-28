@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import Foundation
import XCTest

#if os(iOS) || os(tvOS)

class SentryReplayApiTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }

    // MARK: - Tests

    func testStart_whenReplayIntegrationAlreadyInstalled_shouldCallStartOnExistingIntegration() throws {
        // Arrange
        let options = Options()
        options.sessionReplay.sessionSampleRate = 1.0
        let mockClient = TestClient(options: options)
        let mockReplayIntegration = try XCTUnwrap(MockSessionReplayIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        let mockHub = TestHub(client: mockClient, andScope: Scope())
        mockHub.removeAllIntegrations()
        mockReplayIntegration.addItselfToSentryHub(hub: mockHub)
        SentrySDKInternal.setCurrentHub(mockHub)
        let commandExpectation = expectation(description: "Replay command executed")
        mockReplayIntegration.onCommand = { command in
            if command == "start" {
                commandExpectation.fulfill()
            }
        }
        
        let sut = SentryReplayApi()

        // Act
        sut.start()

        // Assert
        wait(for: [commandExpectation], timeout: 1)
        XCTAssertTrue(mockReplayIntegration.startCalled)
        XCTAssertEqual(mockHub.installedIntegrations().count, 1) // No new integration added
    }

    func testCommands_fromBackgroundThread_shouldExecuteOnMainThreadInCallOrder() throws {
        let options = Options()
        let mockClient = TestClient(options: options)
        let mockReplayIntegration = try XCTUnwrap(MockSessionReplayIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        let mockHub = TestHub(client: mockClient, andScope: Scope())
        mockHub.removeAllIntegrations()
        mockReplayIntegration.addItselfToSentryHub(hub: mockHub)
        SentrySDKInternal.setCurrentHub(mockHub)
        let commandExpectation = expectation(description: "Replay commands executed")
        commandExpectation.expectedFulfillmentCount = 6
        mockReplayIntegration.onCommand = { _ in commandExpectation.fulfill() }
        let sut = SentryReplayApi()

        DispatchQueue.global().async {
            sut.start()
            sut.startBuffering()
            sut.pause()
            sut.resume()
            sut.flush()
            sut.stop()
        }

        wait(for: [commandExpectation], timeout: 1)
        XCTAssertEqual(mockReplayIntegration.commands, ["start", "startBuffering", "pause", "resume", "flush", "stop"])
        XCTAssertEqual(mockReplayIntegration.commandsOnMainThread, Array(repeating: true, count: 6))
    }

    func testStartBuffering_whenReplayIntegrationIsMissing_shouldNotInstall() {
        let oldDebug = SentrySDKLog.isDebug
        let oldLevel = SentrySDKLog.diagnosticLevel
        let oldOutput = SentrySDKLog.getLogOutput()
        defer {
            SentrySDKLog.configureLog(oldDebug, diagnosticLevel: oldLevel)
            SentrySDKLog.setOutput(oldOutput)
        }
        let logOutput = TestLogOutput(logsToConsole: false)
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)
        setHubWithoutReplayIntegration()
        let hub = SentrySDKInternal.currentHub()
        let sut = SentryReplayApi()

        sut.startBuffering()
        waitForMainQueue()

        XCTAssertFalse(hub.installedIntegrations().contains { $0 is SentrySessionReplayIntegration })
        XCTAssertEqual(logOutput.loggedMessages.filter { $0.contains("Session Replay integration is not installed") }.count, 1)
    }

    func testFlush_whenReplayIntegrationIsMissing_shouldNotInstall() {
        setHubWithoutReplayIntegration()
        let hub = SentrySDKInternal.currentHub()
        let sut = SentryReplayApi()

        sut.flush()
        waitForMainQueue()

        XCTAssertFalse(hub.installedIntegrations().contains { $0 is SentrySessionReplayIntegration })
    }

    private func setHubWithoutReplayIntegration() {
        let hub = TestHub(client: TestClient(options: Options()), andScope: Scope())
        hub.removeAllIntegrations()
        SentrySDKInternal.setCurrentHub(hub)
    }

    private func waitForMainQueue() {
        let commandExpectation = expectation(description: "Main queue drained")
        DispatchQueue.main.async { commandExpectation.fulfill() }
        wait(for: [commandExpectation], timeout: 1)
    }
}

private class MockSessionReplayIntegration: SentrySessionReplayIntegration {
    var startCalled = false
    var commands = [String]()
    var commandsOnMainThread = [Bool]()
    var onCommand: ((String) -> Void)?
    
    required convenience init?(with options: Options, dependencies: SentryDependencyContainer) {
        self.init(nonOptionalWith: options, dependencies: dependencies)
    }
    
    @objc override func start() {
        startCalled = true
        record("start")
    }

    @objc override func startBuffering() {
        record("startBuffering")
    }

    @objc override func pause() {
        record("pause")
    }

    @objc override func resume() {
        record("resume")
    }

    @objc override func flush() {
        record("flush")
    }

    @objc override func stop() {
        record("stop")
    }

    private func record(_ command: String) {
        commands.append(command)
        commandsOnMainThread.append(Thread.isMainThread)
        onCommand?(command)
    }
}

#endif // os(iOS) || os(tvOS)
