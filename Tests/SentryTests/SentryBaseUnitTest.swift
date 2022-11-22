import Foundation
import Sentry
import XCTest

class SentryBaseUnitTest: XCTestCase {
    override func setUp() {
        super.setUp()
        do {
            try clearTestState()
        } catch {
            XCTFail("Failed to clear app state at setup.")
        }
    }

    override func tearDown() {
        do {
            try clearTestState()
        } catch {
            XCTFail("Failed to clear app state at teardown.")
        }
        super.tearDown()
    }

    override func setUp() async throws {
        try await super.setUp()
        try clearTestState()
    }

    override func tearDown() async throws {
        try clearTestState()
        try await super.tearDown()
    }
}

private extension SentryBaseUnitTest {
    func clearTestState() throws {
        SentrySDK.close()
        SentrySDK.setCurrentHub(nil)
        SentrySDK.crashedLastRunCalled = false
        SentrySDK.startInvocations = 0

        SentryLog.configure(true, diagnosticLevel: .debug)
        CurrentDate.setCurrentDateProvider(TestCurrentDateProvider())

        SentryTracer.resetAppStartMeasurementRead()
        SentrySDK.setAppStartMeasurement(nil)
        PrivateSentrySDKOnly.onAppStartMeasurementAvailable = nil
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = false

        SentryNetworkTracker.sharedInstance.disable()

        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        let framesTracker = SentryFramesTracker.sharedInstance()
        framesTracker.stop()
        framesTracker.resetFrames()

        setenv("ActivePrewarm", "0", 1)
        SentryAppStartTracker.load()
        #endif

        SentryDependencyContainer.reset()
        Dynamic(SentryGlobalEventProcessor.shared()).removeAllProcessors()
        SentrySwizzleWrapper.sharedInstance.removeAllCallbacks()

        sentrycrash_deleteAllReports()

        let dqw = TestSentryDispatchQueueWrapper()
        let fileManager = try SentryFileManager(options: Options(), andCurrentDateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: dqw)
        fileManager.deleteCurrentSession()
        fileManager.deleteCrashedSession()
        fileManager.deleteTimestampLastInForeground()
        fileManager.deleteAppState()
        fileManager.deleteAllEnvelopes()
        fileManager.deleteTimezoneOffset()
        fileManager.deleteAllFolders()
    }
}
