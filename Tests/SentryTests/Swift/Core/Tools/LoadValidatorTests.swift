import ObjectiveC
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class LoadValidatorTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var mockBinaryImageInfo: SentryBinaryImageInfo!
    private var testOutput: TestLogOutput!
    private var testObjCRuntimeWrapper: SentryTestObjCRuntimeWrapper!
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        testOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(testOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)
        
        testObjCRuntimeWrapper = SentryTestObjCRuntimeWrapper()
        
        mockBinaryImageInfo = SentryBinaryImageInfo()
        mockBinaryImageInfo.name = "/path/to/test/image.dylib"
        mockBinaryImageInfo.address = 0x1000
        mockBinaryImageInfo.size = 0x1000
    }
    
    override func tearDown() {
        clearTestState()
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    func testValidateSDKPresenceIn_SystemLibraryPath_DoesNotValidate() {
        // Arrange
        mockBinaryImageInfo.name = "/usr/lib/system.dylib"
        var getClassListCalled = false
        testObjCRuntimeWrapper.beforeGetClassList = {
            getClassListCalled = true
        }
        
        // Act
        let validationResult = LoadValidator.validateSDKPresenceInSync(mockBinaryImageInfo, objcRuntimeWrapper: testObjCRuntimeWrapper)
        
        // Assert
        XCTAssertFalse(validationResult, "Validation should skip for system libraries")
        XCTAssertFalse(getClassListCalled, "ObjectiveC Wrapper shouldd not be called for a system library")
        XCTAssertFalse(testOutput.loggedMessages.contains { $0.contains("❌ Sentry SDK was loaded multiple times") })
    }
 
#if targetEnvironment(simulator)
    func testValidateSDKPresenceIn_SimulatorPath_DoesNotValidate() {
        // Arrange
        mockBinaryImageInfo.name = "/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/usr/lib/system.dylib"
        var getClassListCalled = false
        testObjCRuntimeWrapper.beforeGetClassList = {
            getClassListCalled = true
        }
        
        // Act
        let validationResult = LoadValidator.validateSDKPresenceInSync(mockBinaryImageInfo, objcRuntimeWrapper: testObjCRuntimeWrapper)
        
        // Assert
        XCTAssertFalse(validationResult, "Validation should skip for simulator libraries")
        XCTAssertFalse(getClassListCalled, "ObjectiveC Wrapper shouldd not be called for a simulator library")
        XCTAssertFalse(testOutput.loggedMessages.contains { $0.contains("❌ Sentry SDK was loaded multiple times") })
    }
#endif
    
    func testValidateSDKPresenceIn_AppImage_CallsRuntimeWrapper() {
        // Arrange
        mockBinaryImageInfo.name = "/var/containers/Bundle/Application/TestApp.app/TestApp"
        var getClassListCalled = false
        testObjCRuntimeWrapper.beforeGetClassList = {
            getClassListCalled = true
        }
        
        // Act
        LoadValidator.validateSDKPresenceInSync(mockBinaryImageInfo, objcRuntimeWrapper: testObjCRuntimeWrapper)
        
        // Assert
        XCTAssertTrue(getClassListCalled, "ObjectiveC Wrapper should be called for an app binary")
        XCTAssertFalse(testOutput.loggedMessages.contains { $0.contains("❌ Sentry SDK was loaded multiple times") })
    }

    func testValidateSDKPresenceIn_ContainsTargetClassName_LogsError() {
        // Arrange
        mockBinaryImageInfo.name = "/var/containers/Bundle/Application/TestApp.app/TestApp"
        testObjCRuntimeWrapper.classesNames = { _ in
            return ["PrivateSentrySDKOnly"]
        }
        var getClassListCalled = false
        testObjCRuntimeWrapper.beforeGetClassList = {
            getClassListCalled = true
        }
        
        // Act
        let validationResult = LoadValidator.validateSDKPresenceInSync(mockBinaryImageInfo, objcRuntimeWrapper: testObjCRuntimeWrapper)
        
        // Assert
        XCTAssertTrue(validationResult, "Validation should skip for app binary")
        XCTAssertTrue(getClassListCalled, "ObjectiveC Wrapper shouldd be called for an app binary")
        XCTAssertTrue(testOutput.loggedMessages.contains { $0.contains("❌ Sentry SDK was loaded multiple times in the binary ❌") })
        XCTAssertTrue(testOutput.loggedMessages.contains { $0.contains("⚠️ This can cause undefined behavior, crashes, or duplicate reporting.") })
        XCTAssertTrue(testOutput.loggedMessages.contains { $0.contains("Ensure the SDK is linked only once, found classes in image paths: \(mockBinaryImageInfo.name)") })
    }
    
    func testValidateSDKPresenceIn_ContainsSubclass_LogsError() {
        // Arrange
        mockBinaryImageInfo.name = "/var/containers/Bundle/Application/TestApp.app/TestApp"
        testObjCRuntimeWrapper.classesNames = { _ in
            return ["EmergePrivateSentrySDKOnly"]
        }
        var getClassListCalled = false
        testObjCRuntimeWrapper.beforeGetClassList = {
            getClassListCalled = true
        }
        
        // Act
        let validationResult = LoadValidator.validateSDKPresenceInSync(mockBinaryImageInfo, objcRuntimeWrapper: testObjCRuntimeWrapper)
        
        // Assert
        XCTAssertTrue(validationResult, "Validation should return true for app")
        XCTAssertTrue(getClassListCalled, "ObjectiveC Wrapper should be called for an app binary")
        XCTAssertTrue(testOutput.loggedMessages.contains { $0.contains("❌ Sentry SDK was loaded multiple times in the binary ❌") })
        XCTAssertTrue(testOutput.loggedMessages.contains { $0.contains("⚠️ This can cause undefined behavior, crashes, or duplicate reporting.") })
        XCTAssertTrue(testOutput.loggedMessages.contains { $0.contains("Ensure the SDK is linked only once, found classes in image paths: \(mockBinaryImageInfo.name)") })
    }

    func testValidateSDKPresenceIn_ContainsTargetClassNameInCurrentImage_SkipsValidation() {
        // Arrange
        mockBinaryImageInfo.name = "/path/to/sentry/libSentry.dylib"
        let loadValidatorAddress = LoadValidator.getCurrentFrameworkTextPointer()
        let loadValidatorAddressValue = UInt(bitPattern: loadValidatorAddress)
        mockBinaryImageInfo.address = UInt64(loadValidatorAddressValue)
        mockBinaryImageInfo.size = 0x1000
        var getClassListCalled = false
        testObjCRuntimeWrapper.beforeGetClassList = {
            getClassListCalled = true
        }
        testObjCRuntimeWrapper.classesNames = { _ in
            return ["PrivateSentrySDKOnly"]
        }
        
        // Act
        let validationResult = LoadValidator.validateSDKPresenceInSync(mockBinaryImageInfo, objcRuntimeWrapper: testObjCRuntimeWrapper)
        
        // Assert
        XCTAssertFalse(validationResult, "Validation should skip for sentry framework")
        XCTAssertTrue(getClassListCalled, "ObjectiveC Wrapper should not be called for an app binary")
        XCTAssertFalse(testOutput.loggedMessages.contains { $0.contains("❌ Sentry SDK was loaded multiple times") })
    }
}
