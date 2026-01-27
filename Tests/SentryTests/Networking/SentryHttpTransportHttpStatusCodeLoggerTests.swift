@_spi(Private) @testable import Sentry
import XCTest

final class SentryHttpTransportHttpStatusCodeLoggerTests: XCTestCase {

    // MARK: - HTTP 413 Tests

    func testLogHttpResponseError_when413WithSingleItem_shouldLogCorrectMessage() throws {
        // Arrange
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .error)

        let event = Event()
        event.message = SentryMessage(formatted: "Test message")
        let envelope = SentryEnvelope(event: event)
        let request = try createRequest(with: envelope)
        let sizeInBytes = request.httpBody?.count ?? 0

        // Act
        SentryHttpTransportHttpStatusCodeLogger.logHttpResponseError(statusCode: SentryHttpStatusCodes.contentTooLarge.rawValue, envelope: envelope, request: request)

        // Assert
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("[Sentry] [error]") &&
            $0.contains("Upstream returned HTTP 413 Content Too Large") &&
            $0.contains("The envelope size in bytes (compressed): \(sizeInBytes)") &&
            $0.contains("item types ( event )")
        }
        XCTAssertEqual(logMessages.count, 1)
    }

    func testLogHttpResponseError_when413WithMultipleItems_shouldListAllTypes() throws {
        // Arrange
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .error)

        let event = Event()
        event.message = SentryMessage(formatted: "Test message")
        let session = SentrySession(releaseName: "1.0.0", distinctId: "user-123")
        let attachment = TestData.dataAttachment
        let attachmentItem = try XCTUnwrap(SentryEnvelopeItem(attachment: attachment, maxAttachmentSize: 1_000_000))

        let envelope = SentryEnvelope(
            id: event.eventId,
            items: [
                SentryEnvelopeItem(event: event),
                SentryEnvelopeItem(session: session),
                attachmentItem
            ]
        )
        let request = try createRequest(with: envelope)

        // Act
        SentryHttpTransportHttpStatusCodeLogger.logHttpResponseError(statusCode: SentryHttpStatusCodes.contentTooLarge.rawValue, envelope: envelope, request: request)

        // Assert
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("item types ( event, session, attachment )")
        }
        XCTAssertEqual(logMessages.count, 1)
    }

    func testLogHttpResponseError_when413WithDuplicateTypes_shouldNotDeduplicate() throws {
        // Arrange
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .error)

        let event1 = Event()
        event1.message = SentryMessage(formatted: "First event")
        let event2 = Event()
        event2.message = SentryMessage(formatted: "Second event")

        let envelope = SentryEnvelope(
            id: event1.eventId,
            items: [
                SentryEnvelopeItem(event: event1),
                SentryEnvelopeItem(event: event2)
            ]
        )
        let request = try createRequest(with: envelope)

        // Act
        SentryHttpTransportHttpStatusCodeLogger.logHttpResponseError(statusCode: SentryHttpStatusCodes.contentTooLarge.rawValue, envelope: envelope, request: request)

        // Assert
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("item types ( event, event )")
        }
        XCTAssertEqual(logMessages.count, 1)
    }

    func testLogHttpResponseError_when413WithEmptyEnvelope_shouldHandleGracefully() throws {
        // Arrange
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .error)

        let envelope = SentryEnvelope(id: nil, items: [])
        let request = try createRequest(with: envelope)

        // Act
        SentryHttpTransportHttpStatusCodeLogger.logHttpResponseError(statusCode: SentryHttpStatusCodes.contentTooLarge.rawValue, envelope: envelope, request: request)

        // Assert
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("item types (  )")
        }
        XCTAssertEqual(logMessages.count, 1)
    }

    func testLogHttpResponseError_when413WithNoRequestBody_shouldReportZeroSize() throws {
        // Arrange
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .error)

        let event = Event()
        let envelope = SentryEnvelope(event: event)
        let url = try XCTUnwrap(URL(string: "https://sentry.io/api/123/envelope/"))
        var request = URLRequest(url: url)
        request.httpBody = nil

        // Act
        SentryHttpTransportHttpStatusCodeLogger.logHttpResponseError(statusCode: SentryHttpStatusCodes.contentTooLarge.rawValue, envelope: envelope, request: request)

        // Assert
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("The envelope size in bytes (compressed): 0")
        }
        XCTAssertEqual(logMessages.count, 1)
    }

    func testLogHttpResponseError_when413_shouldPreserveItemOrder() throws {
        // Arrange
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .error)

        let event = Event()
        let session = SentrySession(releaseName: "1.0.0", distinctId: "user-123")
        let attachment = TestData.dataAttachment
        let attachmentItem = try XCTUnwrap(SentryEnvelopeItem(attachment: attachment, maxAttachmentSize: 1_000_000))

        let envelope = SentryEnvelope(
            id: event.eventId,
            items: [
                attachmentItem,
                SentryEnvelopeItem(event: event),
                SentryEnvelopeItem(session: session)
            ]
        )
        let request = try createRequest(with: envelope)

        // Act
        SentryHttpTransportHttpStatusCodeLogger.logHttpResponseError(statusCode: SentryHttpStatusCodes.contentTooLarge.rawValue, envelope: envelope, request: request)

        // Assert
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("item types ( attachment, event, session )")
        }
        XCTAssertEqual(logMessages.count, 1)
    }

    // MARK: - Non-413 Status Code Tests

    func testLogHttpResponseError_when412_shouldNotLog() throws {
        // Arrange
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .error)

        let event = Event()
        let envelope = SentryEnvelope(event: event)
        let request = try createRequest(with: envelope)

        // Act
        SentryHttpTransportHttpStatusCodeLogger.logHttpResponseError(statusCode: SentryHttpStatusCodes.preconditionFailed.rawValue, envelope: envelope, request: request)

        // Assert
        XCTAssertEqual(logOutput.loggedMessages.count, 0)
    }

    func testLogHttpResponseError_when429_shouldNotLog() throws {
        // Arrange
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .error)

        let event = Event()
        let envelope = SentryEnvelope(event: event)
        let request = try createRequest(with: envelope)

        // Act
        SentryHttpTransportHttpStatusCodeLogger.logHttpResponseError(statusCode: SentryHttpStatusCodes.tooManyRequests.rawValue, envelope: envelope, request: request)

        // Assert
        XCTAssertEqual(logOutput.loggedMessages.count, 0)
    }

    func testLogHttpResponseError_when500_shouldNotLog() throws {
        // Arrange
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .error)

        let event = Event()
        let envelope = SentryEnvelope(event: event)
        let request = try createRequest(with: envelope)

        // Act
        SentryHttpTransportHttpStatusCodeLogger.logHttpResponseError(statusCode: SentryHttpStatusCodes.internalServerError.rawValue, envelope: envelope, request: request)

        // Assert
        XCTAssertEqual(logOutput.loggedMessages.count, 0)
    }

    func testLogHttpResponseError_when200_shouldNotLog() throws {
        // Arrange
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .error)

        let event = Event()
        let envelope = SentryEnvelope(event: event)
        let request = try createRequest(with: envelope)

        // Act
        SentryHttpTransportHttpStatusCodeLogger.logHttpResponseError(statusCode: SentryHttpStatusCodes.ok.rawValue, envelope: envelope, request: request)

        // Assert
        XCTAssertEqual(logOutput.loggedMessages.count, 0)
    }

    // MARK: - Helper Methods

    private func createRequest(with envelope: SentryEnvelope) throws -> URLRequest {
        let data = try XCTUnwrap(SentrySerializationSwift.data(with: envelope))
        let dsn = try SentryDsn(string: "https://username@sentry.io/123")
        return try SentryURLRequestFactory.envelopeRequest(with: dsn, data: data)
    }
}
