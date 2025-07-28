import ObjectiveC
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class LoadValidatorTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var testOutput: TestLogOutput!
    private var testObjCRuntimeWrapper: SentryTestObjCRuntimeWrapper!
    private var dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
    private var defaultImageAddress: UInt64 = 0x1000
    private var defaultImageSize: UInt64 = 0x20
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        testOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(testOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)
        
        testObjCRuntimeWrapper = SentryTestObjCRuntimeWrapper()
        
        dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        dispatchQueueWrapper.dispatchAfterExecutesBlock = true
    }
    
    override func tearDown() {
        clearTestState()
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    func testValidateSDKPresenceIn_SystemLibraryPath_DoesNotValidate() {
        // Arrange
        let imageName = "/usr/lib/system.dylib"
        var getClassListCalled = false
        testObjCRuntimeWrapper.beforeGetClassList = {
            getClassListCalled = true
        }
        let expectation = XCTestExpectation(description: "LoadValidation should complete")
        
        // Act
        var validationResult = false
        LoadValidator.internalCheckForDuplicatedSDK(imageName,
                                                    defaultImageAddress,
                                                    defaultImageSize,
                                                    objcRuntimeWrapper: testObjCRuntimeWrapper,
                                                    dispatchQueueWrapper: dispatchQueueWrapper) { result in
            validationResult = result
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        
        // Assert
        XCTAssertFalse(validationResult, "Validation should return false for system libraries")
        XCTAssertFalse(getClassListCalled, "ObjectiveC Wrapper should not be called for a system library")
        XCTAssertFalse(testOutput.loggedMessages.contains { $0.contains("❌ Sentry SDK was loaded multiple times") })
        XCTAssertEqual(dispatchQueueWrapper.dispatchAsyncInvocations.count, 0)
    }
 
    func testValidateSDKPresenceIn_SimulatorPath_DoesNotValidate() {
        // Arrange
        let imageName = "/Library/Developer/CoreSimulator/Volumes/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/usr/lib/system.dylib"
        var getClassListCalled = false
        testObjCRuntimeWrapper.beforeGetClassList = {
            getClassListCalled = true
        }
        let expectation = XCTestExpectation(description: "LoadValidation should complete")
        
        // Act
        var validationResult = false
        LoadValidator.internalCheckForDuplicatedSDK(imageName,
                                                    defaultImageAddress,
                                                    defaultImageSize,
                                                    objcRuntimeWrapper: testObjCRuntimeWrapper,
                                                    dispatchQueueWrapper: dispatchQueueWrapper) { result in
            validationResult = result
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        
        // Assert
        XCTAssertFalse(validationResult, "Validation should return false for simulator libraries")
        XCTAssertFalse(getClassListCalled, "ObjectiveC Wrapper should not be called for a simulator library")
        XCTAssertFalse(testOutput.loggedMessages.contains { $0.contains("❌ Sentry SDK was loaded multiple times") })
        XCTAssertEqual(dispatchQueueWrapper.dispatchAsyncInvocations.count, 0)
    }
    
    func testValidateSDKPresenceIn_SystemPath_DoesNotValidate() {
        // Arrange
        let imageName = "/System/Library/system.dylib"
        var getClassListCalled = false
        testObjCRuntimeWrapper.beforeGetClassList = {
            getClassListCalled = true
        }
        let expectation = XCTestExpectation(description: "LoadValidation should complete")
        
        // Act
        var validationResult = false
        LoadValidator.internalCheckForDuplicatedSDK(imageName,
                                                    defaultImageAddress,
                                                    defaultImageSize,
                                                    objcRuntimeWrapper: testObjCRuntimeWrapper,
                                                    dispatchQueueWrapper: dispatchQueueWrapper) { result in
            validationResult = result
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        
        // Assert
        XCTAssertFalse(validationResult, "Validation should return false for system libraries")
        XCTAssertFalse(getClassListCalled, "ObjectiveC Wrapper should not be called for a simulator library")
        XCTAssertFalse(testOutput.loggedMessages.contains { $0.contains("❌ Sentry SDK was loaded multiple times") })
        XCTAssertEqual(dispatchQueueWrapper.dispatchAsyncInvocations.count, 0)
    }
    
    func testValidateSDKPresenceIn_AppImage_CallsRuntimeWrapper() {
        // Arrange
        let imageName = "/var/containers/Bundle/Application/TestApp.app/TestApp"
        var getClassListCalled = false
        testObjCRuntimeWrapper.beforeGetClassList = {
            getClassListCalled = true
        }
        let expectation = XCTestExpectation(description: "LoadValidation should complete")
        
        // Act
        var validationResult = false
        LoadValidator.internalCheckForDuplicatedSDK(imageName,
                                                    defaultImageAddress,
                                                    defaultImageSize,
                                                    objcRuntimeWrapper: testObjCRuntimeWrapper,
                                                    dispatchQueueWrapper: dispatchQueueWrapper) { result in
            validationResult = result
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        
        // Assert
        XCTAssertFalse(validationResult, "Validation should return false")
        XCTAssertTrue(getClassListCalled, "ObjectiveC Wrapper should be called for an app binary")
        XCTAssertFalse(testOutput.loggedMessages.contains { $0.contains("❌ Sentry SDK was loaded multiple times") })
        XCTAssertEqual(dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }

    func testValidateSDKPresenceIn_ContainsTargetClassName_LogsError() {
        // Arrange
        let imageName = "/var/containers/Bundle/Application/TestApp.app/TestApp"
        testObjCRuntimeWrapper.classesNames = { _ in
            return ["SentryDependencyContainerSwiftHelper"]
        }
        var getClassListCalled = false
        testObjCRuntimeWrapper.beforeGetClassList = {
            getClassListCalled = true
        }
        let expectation = XCTestExpectation(description: "LoadValidation should complete")
        
        // Act
        var validationResult = false
        LoadValidator.internalCheckForDuplicatedSDK(imageName,
                                                    defaultImageAddress,
                                                    defaultImageSize,
                                                    objcRuntimeWrapper: testObjCRuntimeWrapper,
                                                    dispatchQueueWrapper: dispatchQueueWrapper) { result in
            validationResult = result
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        
        // Assert
        XCTAssertTrue(validationResult, "Validation should skip for app binary")
        XCTAssertTrue(getClassListCalled, "ObjectiveC Wrapper should be called for an app binary")
        XCTAssertTrue(testOutput.loggedMessages.contains { $0.contains("❌ Sentry SDK was loaded multiple times in the same binary ❌") })
        XCTAssertTrue(testOutput.loggedMessages.contains { $0.contains("⚠️ This can cause undefined behavior, crashes, or duplicate reporting.") })
        XCTAssertTrue(testOutput.loggedMessages.contains { $0.contains("Ensure the SDK is linked only once, found `SentryDependencyContainerSwiftHelper` class in image path: \(imageName)") })
        XCTAssertEqual(dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }
    
    func testValidateSDKPresenceIn_ContainsSubclass_LogsError() {
        // Arrange
        let imageName = "/var/containers/Bundle/Application/TestApp.app/TestApp"
        testObjCRuntimeWrapper.classesNames = { _ in
            return ["EmergeSentryDependencyContainerSwiftHelper"]
        }
        var getClassListCalled = false
        testObjCRuntimeWrapper.beforeGetClassList = {
            getClassListCalled = true
        }
        let expectation = XCTestExpectation(description: "LoadValidation should complete")
        
        // Act
        var validationResult = false
        LoadValidator.internalCheckForDuplicatedSDK(imageName,
                                                    defaultImageAddress,
                                                    defaultImageSize,
                                                    objcRuntimeWrapper: testObjCRuntimeWrapper,
                                                    dispatchQueueWrapper: dispatchQueueWrapper) { result in
            validationResult = result
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        
        // Assert
        XCTAssertTrue(validationResult, "Validation should return true for app")
        XCTAssertTrue(getClassListCalled, "ObjectiveC Wrapper should be called for an app binary")
        XCTAssertTrue(testOutput.loggedMessages.contains { $0.contains("❌ Sentry SDK was loaded multiple times in the same binary ❌") })
        XCTAssertTrue(testOutput.loggedMessages.contains { $0.contains("⚠️ This can cause undefined behavior, crashes, or duplicate reporting.") })
        XCTAssertTrue(testOutput.loggedMessages.contains { $0.contains("Ensure the SDK is linked only once, found `SentryDependencyContainerSwiftHelper` class in image path: \(imageName)") })
        XCTAssertEqual(dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }

    func testValidateSDKPresenceIn_ContainsTargetClassNameInCurrentImage_SkipsValidation() {
        // Arrange
        let imageName = "/path/to/sentry/libSentry.dylib"
        let loadValidatorAddress = LoadValidator.getCurrentFrameworkTextPointer()
        let loadValidatorAddressValue = UInt(bitPattern: loadValidatorAddress)
        let imageAddress = UInt64(loadValidatorAddressValue)
        let imageSize: UInt64 = 0x1000
        var getClassListCalled = false
        testObjCRuntimeWrapper.beforeGetClassList = {
            getClassListCalled = true
        }
        testObjCRuntimeWrapper.classesNames = { _ in
            return ["SentryDependencyContainerSwiftHelper"]
        }
        let expectation = XCTestExpectation(description: "LoadValidation should complete")
        
        // Act
        var validationResult = false
        LoadValidator.internalCheckForDuplicatedSDK(imageName,
                                                    imageAddress,
                                                    imageSize,
                                                    objcRuntimeWrapper: testObjCRuntimeWrapper,
                                                    dispatchQueueWrapper: dispatchQueueWrapper) { result in
            validationResult = result
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        
        // Assert
        XCTAssertFalse(validationResult, "Validation should skip for sentry framework")
        XCTAssertTrue(getClassListCalled, "ObjectiveC Wrapper should not be called for an app binary")
        XCTAssertFalse(testOutput.loggedMessages.contains { $0.contains("❌ Sentry SDK was loaded multiple times") })
        XCTAssertEqual(dispatchQueueWrapper.dispatchAsyncInvocations.count, 1)
    }
}
