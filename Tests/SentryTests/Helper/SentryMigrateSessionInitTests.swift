@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

class SentryMigrateSessionInitTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        clearTestState()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    func testMigrateSessionInit_WithNilEnvelopeItemData_DoesNotCrash() {
        // Arrange
        let sessionHeader = SentryEnvelopeItemHeader(type: SentryEnvelopeItemTypes.session, length: 0)
        let sessionItem = SentryEnvelopeItem(header: sessionHeader, data: nil)
        let envelope = SentryEnvelope(header: SentryEnvelopeHeader(id: nil), singleItem: sessionItem)
        
        // Act
        let result = SentryMigrateSessionInit.migrateSessionInit(envelope, 
                                                               envelopesDirPath: "/tmp", 
                                                               envelopeFilePaths: [])
        
        // Assert
        XCTAssertFalse(result, "Migration should return false when session item has nil data")
    }

    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    func testMigrateSessionInit_WithMixedNilAndValidData_DoesNotCrash() throws {
        // Arrange
        let validSession = SentrySession(releaseName: "1.0.0", distinctId: "test-id")
        let validSessionData = try XCTUnwrap(SentrySerialization.data(with: validSession))
        let validSessionHeader = SentryEnvelopeItemHeader(type: SentryEnvelopeItemTypes.session, 
                                                        length: UInt(validSessionData.count))
        let validSessionItem = SentryEnvelopeItem(header: validSessionHeader, data: validSessionData)
        
        let nilSessionHeader = SentryEnvelopeItemHeader(type: SentryEnvelopeItemTypes.session, length: 0)
        let nilSessionItem = SentryEnvelopeItem(header: nilSessionHeader, data: nil)
        
        let envelope = SentryEnvelope(header: SentryEnvelopeHeader(id: nil), 
                                    items: [validSessionItem, nilSessionItem])
        
        // Act
        let result = SentryMigrateSessionInit.migrateSessionInit(envelope, 
                                                               envelopesDirPath: "/tmp", 
                                                               envelopeFilePaths: [])
        
        // Assert
        XCTAssertFalse(result, "Migration should return false when no valid session init items exist")
    }

    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    func testSetInitFlagIfContainsSameSessionId_WithNilEnvelopeItemData_DoesNotCrash() {
        // Arrange
        let session = SentrySession(releaseName: "1.0.0", distinctId: "test-id")
        session.setFlagInit()
        
        let sessionHeader = SentryEnvelopeItemHeader(type: SentryEnvelopeItemTypes.session, length: 0)
        let sessionItem = SentryEnvelopeItem(header: sessionHeader, data: nil)
        let envelope = SentryEnvelope(header: SentryEnvelopeHeader(id: nil), singleItem: sessionItem)
        
        // Act
        let result = SentryMigrateSessionInit.setInitFlagIfContainsSameSessionId(session.sessionId, 
                                                                                envelope: envelope, 
                                                                                envelopeFilePath: "/tmp/test")
        
        // Assert
        XCTAssertFalse(result, "Should return false when session item has nil data")
    }

    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    func testSetInitFlagIfContainsSameSessionId_WithMixedNilAndValidData_DoesNotCrash() throws {
        // Arrange
        let session = SentrySession(releaseName: "1.0.0", distinctId: "test-id")
        session.setFlagInit()
        
        let validSession = SentrySession(releaseName: "1.0.0", distinctId: "test-id")
        let validSessionData = try XCTUnwrap(SentrySerialization.data(with: validSession))
        let validSessionHeader = SentryEnvelopeItemHeader(type: SentryEnvelopeItemTypes.session, 
                                                        length: UInt(validSessionData.count))
        let validSessionItem = SentryEnvelopeItem(header: validSessionHeader, data: validSessionData)
        
        let nilSessionHeader = SentryEnvelopeItemHeader(type: SentryEnvelopeItemTypes.session, length: 0)
        let nilSessionItem = SentryEnvelopeItem(header: nilSessionHeader, data: nil)
        
        let envelope = SentryEnvelope(header: SentryEnvelopeHeader(id: nil), 
                                    items: [validSessionItem, nilSessionItem])
        
        // Act
        let result = SentryMigrateSessionInit.setInitFlagIfContainsSameSessionId(session.sessionId, 
                                                                                envelope: envelope, 
                                                                                envelopeFilePath: "/tmp/test")
        
        // Assert
        XCTAssertTrue(result, "Should return true when matching session is found and init flag is set")
    }

    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    func testMigrateSessionInit_WithValidSessionInit_ReturnsTrue() throws {
        // Arrange
        let session = SentrySession(releaseName: "1.0.0", distinctId: "test-id")
        session.setFlagInit()
        let sessionData = try XCTUnwrap(SentrySerialization.data(with: session))
        let sessionHeader = SentryEnvelopeItemHeader(type: SentryEnvelopeItemTypes.session, 
                                                   length: UInt(sessionData.count))
        let sessionItem = SentryEnvelopeItem(header: sessionHeader, data: sessionData)
        let envelope = SentryEnvelope(header: SentryEnvelopeHeader(id: nil), singleItem: sessionItem)
        
        let tempDir = NSTemporaryDirectory()
        let tempFile = "test_envelope.json"
        let tempPath = (tempDir as NSString).appendingPathComponent(tempFile)
        
        // Create a test envelope file with the same session ID but without init flag
        let testSession = SentrySession(releaseName: "1.0.0", distinctId: "test-id")
        // Don't set init flag on test session
        let testSessionData = try XCTUnwrap(SentrySerialization.data(with: testSession))
        let testSessionHeader = SentryEnvelopeItemHeader(type: SentryEnvelopeItemTypes.session, 
                                                       length: UInt(testSessionData.count))
        let testSessionItem = SentryEnvelopeItem(header: testSessionHeader, data: testSessionData)
        let testEnvelope = SentryEnvelope(header: SentryEnvelopeHeader(id: nil), singleItem: testSessionItem)
        let testEnvelopeData = try XCTUnwrap(SentrySerialization.data(with: testEnvelope))
        
        try! testEnvelopeData.write(to: URL(fileURLWithPath: tempPath))
        
        defer {
            try? FileManager.default.removeItem(atPath: tempPath)
        }
        
        // Act
        let result = SentryMigrateSessionInit.migrateSessionInit(envelope, 
                                                               envelopesDirPath: tempDir, 
                                                               envelopeFilePaths: [tempFile])
        
        // Assert
        XCTAssertTrue(result, "Migration should return true when session init is migrated")
    }

    @available(*, deprecated, message: "This is only marked as deprecated because enableAppLaunchProfiling is marked as deprecated. Once that is removed this can be removed.")
    func testWithGarbageParametersDoesNotCrash() throws {
        // Arrange
        let envelope = try XCTUnwrap(SentrySerialization.envelope(with: Data()))

        // Act & Assert - This should not crash
        SentryMigrateSessionInit.migrateSessionInit(envelope, 
                                                   envelopesDirPath: "asdf", 
                                                   envelopeFilePaths: [])
    }
}
