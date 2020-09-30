import XCTest

class SentryMessageTests: XCTestCase {
    
    private class Fixture {
        let stringMaxCount = 8_192
        let maximumCount: String
        let tooLong: String
        
        init() {
            maximumCount = String(repeating: "a", count: stringMaxCount)
            tooLong = String(repeating: "a", count: stringMaxCount + 1)
        }
    }
    
    private let fixture = Fixture()
    
    func testTruncateFormatted() {
        let message = SentryMessage(formatted: "aaaaa")
        XCTAssertEqual(5, message.formatted?.count)
        
        message.formatted = fixture.maximumCount
        XCTAssertEqual(fixture.stringMaxCount, message.formatted?.count)
        
        message.formatted = fixture.tooLong
        XCTAssertEqual(fixture.stringMaxCount, message.formatted?.count)
    }
    
    func testTruncateMessage() {
        let message = SentryMessage()
        message.message = "aaaaa"
        
        XCTAssertEqual(5, message.message?.count)
        
        message.message = fixture.maximumCount
        XCTAssertEqual(fixture.stringMaxCount, message.message?.count)
        
        message.message = fixture.tooLong
        XCTAssertEqual(fixture.stringMaxCount, message.message?.count)
    }
    
    func testSerialize() {
        let message = SentryMessage()
        message.formatted = "Something %s"
        message.message = "A message"
        message.params = ["my", "params"]
        
        let actual = message.serialize()
        
        XCTAssertEqual(message.formatted, actual["formatted"] as? String)
        XCTAssertEqual(message.message, actual["message"] as? String)
        XCTAssertEqual(message.params, actual["params"] as? [String])
    }
}
