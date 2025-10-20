import XCTest

final class SentryTracePropagationTests: XCTestCase {

    func testAddTraceparent_Sampled() throws {
        // Arrange
        let defaultRegex = try XCTUnwrap(NSRegularExpression(pattern: ".*"))
        let emptyBaggage = Baggage()
        let sessionTask = try createSessionTask()

        let traceID = SentryId()
        let spanID = SpanId()
        let traceHeader = TraceHeader(trace: traceID, spanId: spanID, sampled: SentrySampleDecision.yes)

        // Act
        SentryTracePropagation.addBaggageHeader(emptyBaggage, traceHeader: traceHeader, propagateTraceparent: true, tracePropagationTargets: [defaultRegex], toRequest: sessionTask)

        // Assert
        let traceParent = try XCTUnwrap(sessionTask.currentRequest?.allHTTPHeaderFields?["traceparent"])
        XCTAssertEqual(traceParent, "00-\(traceID.sentryIdString)-\(spanID.sentrySpanIdString)-01")
    }

    func testAddTraceparent_NotSampled() throws {
        // Arrange
        let defaultRegex = try XCTUnwrap(NSRegularExpression(pattern: ".*"))
        let emptyBaggage = Baggage()
        let sessionTask = try createSessionTask()

        let traceID = SentryId()
        let spanID = SpanId()
        let traceHeader = TraceHeader(trace: traceID, spanId: spanID, sampled: SentrySampleDecision.no)

        // Act
        SentryTracePropagation.addBaggageHeader(emptyBaggage, traceHeader: traceHeader, propagateTraceparent: true, tracePropagationTargets: [defaultRegex], toRequest: sessionTask)

        // Assert
        let traceParent = try XCTUnwrap(sessionTask.currentRequest?.allHTTPHeaderFields?["traceparent"])
        XCTAssertEqual(traceParent, "00-\(traceID.sentryIdString)-\(spanID.sentrySpanIdString)-00")
    }

    func testAddTraceparent_UndecidedSampled() throws {
        // Arrange
        let defaultRegex = try XCTUnwrap(NSRegularExpression(pattern: ".*"))
        let emptyBaggage = Baggage()
        let sessionTask = try createSessionTask()

        let traceID = SentryId()
        let spanID = SpanId()
        let traceHeader = TraceHeader(trace: traceID, spanId: spanID, sampled: SentrySampleDecision.undecided)

        // Act
        SentryTracePropagation.addBaggageHeader(emptyBaggage, traceHeader: traceHeader, propagateTraceparent: true, tracePropagationTargets: [defaultRegex], toRequest: sessionTask)

        // Assert
        let traceParent = try XCTUnwrap(sessionTask.currentRequest?.allHTTPHeaderFields?["traceparent"])
        XCTAssertEqual(traceParent, "00-\(traceID.sentryIdString)-\(spanID.sentrySpanIdString)-00")
    }

    func testAddTraceparent_NotAddedWhenTargetDoesntMatch() throws {
        // Arrange
        let emptyBaggage = Baggage()
        let sessionTask = try createSessionTask()

        let traceID = SentryId()
        let spanID = SpanId()
        let traceHeader = TraceHeader(trace: traceID, spanId: spanID, sampled: SentrySampleDecision.no)

        // Act
        SentryTracePropagation.addBaggageHeader(emptyBaggage, traceHeader: traceHeader, propagateTraceparent: true, tracePropagationTargets: ["localhost"], toRequest: sessionTask)

        // Assert
        XCTAssertNil(sessionTask.currentRequest?.allHTTPHeaderFields?["traceparent"])
    }

    func testIsTargetMatchWithDefaultRegex_MatchesAllURLs() throws {
        // Arrange
        let defaultRegex = try XCTUnwrap(NSRegularExpression(pattern: ".*"))
        let localhostURL = try XCTUnwrap(URL(string: "http://localhost"))
        let exampleURL = try XCTUnwrap(URL(string: "http://www.example.com/api/projects"))
        
        // Act & Assert
        XCTAssertTrue(SentryTracePropagation.isTargetMatch(localhostURL, withTargets: [defaultRegex]))
        XCTAssertTrue(SentryTracePropagation.isTargetMatch(exampleURL, withTargets: [defaultRegex]))
    }
    
    func testIsTargetMatchWithStringHostname_MatchesExactHostname() throws {
        // Arrange
        let localhostURL = try XCTUnwrap(URL(string: "http://localhost"))
        let exampleURL = try XCTUnwrap(URL(string: "http://www.example.com/api/projects"))
        let apiExampleURL = try XCTUnwrap(URL(string: "http://api.example.com/api/projects"))
        let localhostTargets = ["localhost"]
        let exampleTargets = ["www.example.com"]
        
        // Act & Assert
        XCTAssertTrue(SentryTracePropagation.isTargetMatch(localhostURL, withTargets: localhostTargets))
        XCTAssertFalse(SentryTracePropagation.isTargetMatch(exampleURL, withTargets: localhostTargets))
        XCTAssertFalse(SentryTracePropagation.isTargetMatch(localhostURL, withTargets: exampleTargets))
        XCTAssertTrue(SentryTracePropagation.isTargetMatch(exampleURL, withTargets: exampleTargets))
        XCTAssertFalse(SentryTracePropagation.isTargetMatch(apiExampleURL, withTargets: exampleTargets))
    }
    
    func testIsTargetMatchWithStringHostname_MatchesSubstrings() throws {
        // Arrange
        let localhostExtendedURL = try XCTUnwrap(URL(string: "http://localhost-but-not-really"))
        let evilURL = try XCTUnwrap(URL(string: "http://www.example.com.evil.com/api/projects"))
        let localhostTargets = ["localhost"]
        let exampleTargets = ["www.example.com"]
        
        // Act & Assert
        XCTAssertTrue(SentryTracePropagation.isTargetMatch(localhostExtendedURL, withTargets: localhostTargets))
        XCTAssertTrue(SentryTracePropagation.isTargetMatch(evilURL, withTargets: exampleTargets))
    }
    
    func testIsTargetMatchWithRegexPattern_MatchesSpecificPatterns() throws {
        // Arrange
        let regex = try XCTUnwrap(NSRegularExpression(pattern: "http://www.example.com/api/.*"))
        let localhostURL = try XCTUnwrap(URL(string: "http://localhost"))
        let nonAPIURL = try XCTUnwrap(URL(string: "http://www.example.com/url"))
        let apiURL = try XCTUnwrap(URL(string: "http://www.example.com/api/projects"))
        
        // Act & Assert
        XCTAssertFalse(SentryTracePropagation.isTargetMatch(localhostURL, withTargets: [regex]))
        XCTAssertFalse(SentryTracePropagation.isTargetMatch(nonAPIURL, withTargets: [regex]))
        XCTAssertTrue(SentryTracePropagation.isTargetMatch(apiURL, withTargets: [regex]))
    }
    
    func testIsTargetMatchWithMixedRegexAndString_MatchesEitherTarget() throws {
        // Arrange
        let regex = try XCTUnwrap(NSRegularExpression(pattern: "http://www.example.com/api/.*"))
        let localhostURL = try XCTUnwrap(URL(string: "http://localhost"))
        let nonAPIURL = try XCTUnwrap(URL(string: "http://www.example.com/url"))
        let apiURL = try XCTUnwrap(URL(string: "http://www.example.com/api/projects"))
        let mixedTargets = ["localhost", regex] as [Any]
        
        // Act & Assert
        XCTAssertTrue(SentryTracePropagation.isTargetMatch(localhostURL, withTargets: mixedTargets))
        XCTAssertFalse(SentryTracePropagation.isTargetMatch(nonAPIURL, withTargets: mixedTargets))
        XCTAssertTrue(SentryTracePropagation.isTargetMatch(apiURL, withTargets: mixedTargets))
    }
    
    func testIsTargetMatchWithInvalidInput_DoesNotCrash() throws {
        // Arrange
        let localhostURL = try XCTUnwrap(URL(string: "http://localhost"))
        let targetsWithInvalidType = ["localhost", 123] as [Any]
        
        // Act & Assert
        XCTAssertTrue(SentryTracePropagation.isTargetMatch(localhostURL, withTargets: targetsWithInvalidType))
    }

    private func createSessionTask(method: String = "GET") throws -> URLSessionDownloadTaskMock {
        let url = try XCTUnwrap(URL(string: "https://www.domain.com/api?query=value&query2=value2#fragment"))
        var request = URLRequest(url: url)
        request.httpMethod = method
        return URLSessionDownloadTaskMock(request: request)
    }

}
