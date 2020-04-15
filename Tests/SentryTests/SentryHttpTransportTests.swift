import XCTest

class SentryHttpTransportTests: XCTestCase {
    
    private let defaultRetryAfterInSeconds = 60.0

    private var fileManager: SentryFileManager!
    private var options: Options!
    private var requestManager: TestRequestManager!
    private var currentDateProvider: TestCurrentDateProvider!
    private var sut: SentryHttpTransport!
    
    override func setUp() {
        currentDateProvider = TestCurrentDateProvider()
        CurrentDate.setCurrentDateProvider(currentDateProvider)
        
        do {
            fileManager = try SentryFileManager.init(dsn: TestConstants.dsn)
            
            requestManager = TestRequestManager(session: URLSession())
            options = try Options(dict: ["dsn": TestConstants.dsnAsString])
            sut = SentryHttpTransport(
                options: options,
                sentryFileManager: fileManager,
                sentryRequestManager: requestManager
            )
        } catch {
            XCTFail("SentryHttpTransport could not be created")
        }
    }

    func testSendOneEvent()  {
        sendEvent()
        
        XCTAssertEqual(1, requestManager.requests.count)
    }
    
    func testOptionsDisabled() {
        options.enabled = false
        sendEvent()
        sendEvent()
        
        XCTAssertEqual(0, requestManager.requests.count)
    }
    
    func testRetryAfterHeaderDeltaSeconds() {
        testRetryHeaderWith1Second(value: "1")
    }
    
    func testRetryAfterHeaderHttpDate() {
        let headerValue = formatAsHttpDate(date: CurrentDate.date().addingTimeInterval(1))
        testRetryHeaderWith1Second(value: headerValue)
    }
    
    private func testRetryHeaderWith1Second(value: String) {
        let response = createRetryAfterHeader(headerValue: value)
        requestManager.returnResponse(response: response)
        
        // First response parses Retry-After header
        sendEvent()
        XCTAssertEqual(1, requestManager.requests.count)
        
        // Retry-After almost expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(0.999))
        sendEvent()
        XCTAssertEqual(1, requestManager.requests.count)
        
        // Retry-After expired
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        sendEvent()
        XCTAssertEqual(2, requestManager.requests.count)
    }
    
    func testFaultyRetryAfterHeader() {
        let response = createRetryAfterHeader(headerValue: "ABC")
        
        assertSetsDefaultRetryAfter(response: response)
    }
    
    func testRetryAfterHeaderIsEmpty() {
        let response = createRetryAfterHeader(headerValue: "")
     
        assertSetsDefaultRetryAfter(response: response)
    }
    
    private func sendEvent() {
        sut.send(event: Event(), completion: nil)
    }
    
    private func createRetryAfterHeader(headerValue: String) -> HTTPURLResponse {
        return HTTPURLResponse.init(
            url: URL.init(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": headerValue])!
    }
    
    private func assertSetsDefaultRetryAfter(response: HTTPURLResponse) {
        requestManager.returnResponse(response: response)
        sendEvent()
        
        sendEvent()
        XCTAssertEqual(1, requestManager.requests.count)
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(defaultRetryAfterInSeconds))
        sendEvent()
        XCTAssertEqual(2, requestManager.requests.count)
    }
    
    private func formatAsHttpDate(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"
        dateFormatter.timeZone = TimeZone.init(abbreviation: "GMT")
        
        return dateFormatter.string(from: date)
    }
}
