#if os(iOS) || os(tvOS)

@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryWatchdogTerminationLogicTests: XCTestCase {
    
    private static let dsn = TestConstants.dsnForTestCase(type: SentryWatchdogTerminationLogicTests.self)
    
    private struct Fixture {
        let options: Options
        let crashWrapper: TestSentryCrashWrapper
        let fileManager: SentryFileManager
        let sysctl: TestSysctl
        let dispatchQueue: TestSentryDispatchQueueWrapper
        
        init() throws {
            sysctl = TestSysctl()
            SentryDependencyContainer.sharedInstance().sysctlWrapper = sysctl
            
            options = Options()
            options.dsn = SentryWatchdogTerminationLogicTests.dsn
            options.enableWatchdogTerminationTracking = true
            options.releaseName = "1.0.0"
            
            dispatchQueue = TestSentryDispatchQueueWrapper()
            let dateProvider = TestCurrentDateProvider()
            fileManager = try XCTUnwrap(SentryFileManager(options: options, dateProvider: dateProvider, dispatchQueueWrapper: dispatchQueue))
            
            crashWrapper = TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo)
        }
        
        func getSut(customCurrentAppState: SentryAppState? = nil) -> SentryWatchdogTerminationLogic {
            let appStateManager: SentryAppStateManager
            
            if let customState = customCurrentAppState {
                appStateManager = SentryAppStateManager(
                    releaseName: options.releaseName,
                    crashWrapper: crashWrapper,
                    fileManager: fileManager,
                    sysctlWrapper: sysctl,
                    customBuildCurrentAppState: { customState }
                )
            } else {
                appStateManager = SentryAppStateManager(
                    releaseName: options.releaseName,
                    crashWrapper: crashWrapper,
                    fileManager: fileManager,
                    sysctlWrapper: sysctl
                )
            }
            
            return SentryWatchdogTerminationLogic(
                options: options,
                crashAdapter: crashWrapper,
                appStateManager: appStateManager
            )
        }
        
        func createAppState(
            releaseName: String? = "1.0.0",
            osVersion: String = "17.0",
            vendorId: String? = TestData.someUUID,
            isDebugging: Bool = false,
            isActive: Bool = true,
            wasTerminated: Bool = false,
            isSDKRunning: Bool = true,
            isANROngoing: Bool = false
        ) -> SentryAppState {
            let appState = SentryAppState(
                releaseName: releaseName,
                osVersion: osVersion,
                vendorId: vendorId,
                isDebugging: isDebugging,
                systemBootTimestamp: sysctl.systemBootTimestamp
            )
            appState.isActive = isActive
            appState.wasTerminated = wasTerminated
            appState.isSDKRunning = isSDKRunning
            appState.isANROngoing = isANROngoing
            return appState
        }
        
        func storePreviousAppState(_ appState: SentryAppState) {
            fileManager.store(appState)
            fileManager.moveAppStateToPreviousAppState()
        }
    }
    
    private var fixture: Fixture!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
        SentrySDKInternal.startInvocations = 1
    }
    
    override func tearDown() {
        super.tearDown()
        fixture.fileManager.deleteAllFolders()
        clearTestState()
    }
    
    // MARK: - Watchdog Termination Tracking Disabled
    
    func testIsWatchdogTermination_whenTrackingDisabled_shouldReturnFalse() {
        // -- Arrange --
        fixture.options.enableWatchdogTerminationTracking = false
        let sut = fixture.getSut()
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    // MARK: - No Previous App State
    
    func testIsWatchdogTermination_whenNoPreviousAppState_shouldReturnFalse() {
        // -- Arrange --
        let sut = fixture.getSut()
        // No previous app state stored
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    // MARK: - Simulator Build
    
    func testIsWatchdogTermination_whenSimulatorBuild_shouldReturnFalse() {
        // -- Arrange --
        fixture.crashWrapper.internalIsSimulatorBuild = true
        fixture.storePreviousAppState(fixture.createAppState())
        let sut = fixture.getSut()
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    // MARK: - Release Name Changes
    
    func testIsWatchdogTermination_whenDifferentReleaseName_shouldReturnFalse() {
        // -- Arrange --
        fixture.storePreviousAppState(fixture.createAppState(releaseName: "0.9.0"))
        let currentAppState = fixture.createAppState(releaseName: "1.0.0")
        let sut = fixture.getSut(customCurrentAppState: currentAppState)
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    // MARK: - OS VersVersion Changes
    
    func testIsWatchdogTermination_whenDifferentOSVersion_shouldReturnFalse() {
        // -- Arrange --
        fixture.storePreviousAppState(fixture.createAppState(osVersion: "16.0"))
        let currentAppState = fixture.createAppState(osVersion: "17.0")
        let sut = fixture.getSut(customCurrentAppState: currentAppState)
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    // MARK: - System Boot Timestamp Changes
    
    func testIsWatchdogTermination_whenDifferentBootTimestamp_shouldReturnFalse() {
        // -- Arrange --
        let previousAppState = SentryAppState(
            releaseName: "1.0.0",
            osVersion: "17.0",
            vendorId: TestData.someUUID,
            isDebugging: false,
            systemBootTimestamp: fixture.sysctl.systemBootTimestamp.addingTimeInterval(-3_600)
        )
        previousAppState.isActive = true
        fixture.storePreviousAppState(previousAppState)
        let sut = fixture.getSut()
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    // MARK: - Vendor ID Changes
    
    func testIsWatchdogTermination_whenDifferentVendorId_shouldReturnFalse() {
        // -- Arrange --
        fixture.storePreviousAppState(fixture.createAppState(vendorId: "different-vendor-id"))
        let currentAppState = fixture.createAppState(vendorId: TestData.someUUID)
        let sut = fixture.getSut(customCurrentAppState: currentAppState)
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    func testIsWatchdogTermination_whenPreviousVendorIdNil_shouldReturnFalse() {
        // -- Arrange --
        fixture.storePreviousAppState(fixture.createAppState(vendorId: nil))
        let currentAppState = fixture.createAppState(vendorId: TestData.someUUID)
        let sut = fixture.getSut(customCurrentAppState: currentAppState)
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    func testIsWatchdogTermination_whenCurrentVendorIdNil_shouldReturnFalse() {
        // -- Arrange --
        fixture.storePreviousAppState(fixture.createAppState(vendorId: TestData.someUUID))
        let currentAppState = fixture.createAppState(vendorId: nil)
        let sut = fixture.getSut(customCurrentAppState: currentAppState)
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    func testIsWatchdogTermination_whenBothVendorIdsNil_shouldReturnFalse() {
        // -- Arrange --
        fixture.storePreviousAppState(fixture.createAppState(vendorId: nil))
        let currentAppState = fixture.createAppState(vendorId: nil)
        let sut = fixture.getSut(customCurrentAppState: currentAppState)
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    // MARK: - Debugging
    
    func testIsWatchdogTermination_whenWasDebugging_shouldReturnFalse() {
        // -- Arrange --
        fixture.storePreviousAppState(fixture.createAppState(isDebugging: true))
        let currentAppState = fixture.createAppState()
        let sut = fixture.getSut(customCurrentAppState: currentAppState)
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    // MARK: - Normal Termination
    
    func testIsWatchdogTermination_whenWasTerminated_shouldReturnFalse() {
        // -- Arrange --
        fixture.storePreviousAppState(fixture.createAppState(wasTerminated: true))
        let currentAppState = fixture.createAppState()
        let sut = fixture.getSut(customCurrentAppState: currentAppState)
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    // MARK: - Crash Last Launch
    
    func testIsWatchdogTermination_whenCrashedLastLaunch_shouldReturnFalse() {
        // -- Arrange --
        fixture.crashWrapper.internalCrashedLastLaunch = true
        fixture.storePreviousAppState(fixture.createAppState())
        let currentAppState = fixture.createAppState()
        let sut = fixture.getSut(customCurrentAppState: currentAppState)
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    // MARK: - SDK Not Running
    
    func testIsWatchdogTermination_whenSDKNotRunning_shouldReturnFalse() {
        // -- Arrange --
        fixture.storePreviousAppState(fixture.createAppState(isSDKRunning: false))
        let currentAppState = fixture.createAppState()
        let sut = fixture.getSut(customCurrentAppState: currentAppState)
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    // MARK: - App Not Active
    
    func testIsWatchdogTermination_whenAppNotActive_shouldReturnFalse() {
        // -- Arrange --
        fixture.storePreviousAppState(fixture.createAppState(isActive: false))
        let currentAppState = fixture.createAppState()
        let sut = fixture.getSut(customCurrentAppState: currentAppState)
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    // MARK: - ANR Ongoing
    
    func testIsWatchdogTermination_whenANROngoing_shouldReturnFalse() {
        // -- Arrange --
        fixture.storePreviousAppState(fixture.createAppState(isANROngoing: true))
        let currentAppState = fixture.createAppState()
        let sut = fixture.getSut(customCurrentAppState: currentAppState)
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    // MARK: - SDK Started Multiple Times
    
    func testIsWatchdogTermination_whenSDKStartedMultipleTimes_shouldReturnFalse() {
        // -- Arrange --
        SentrySDKInternal.startInvocations = 2
        fixture.storePreviousAppState(fixture.createAppState())
        let currentAppState = fixture.createAppState()
        let sut = fixture.getSut(customCurrentAppState: currentAppState)
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertFalse(result)
    }
    
    // MARK: - Valid Watchdog Termination
    
    func testIsWatchdogTermination_whenAllConditionsMet_shouldReturnTrue() {
        // -- Arrange --
        fixture.storePreviousAppState(fixture.createAppState())
        let currentAppState = fixture.createAppState()
        let sut = fixture.getSut(customCurrentAppState: currentAppState)
        
        // -- Act --
        let result = sut.isWatchdogTermination()
        
        // -- Assert --
        XCTAssertTrue(result)
    }
}

#endif
