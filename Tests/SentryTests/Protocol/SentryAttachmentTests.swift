import XCTest

class SentryAttachmentTests: XCTestCase {
    
    private class Fixture {
        let defaultContentType = "application/octet-stream"
        let contentType = "application/json"
        let filename = "logs.txt"
        let data = "content".data(using: .utf8)!
        let path: String
        
        let dataAttachment: Attachment
        let fileAttachment: Attachment
        
        init() {
            path = "path/to/\(filename)"
            
            dataAttachment = Attachment(data: data, filename: filename)
            fileAttachment = Attachment(path: path, filename: filename)
        }
    }
    
    private let fixture = Fixture()

    func testInitWithData() {
        let attachment = Attachment(data: fixture.data, filename: fixture.filename)
        
        XCTAssertEqual(fixture.data, attachment.data)
        XCTAssertEqual(fixture.filename, attachment.filename)
        XCTAssertNil(attachment.contentType)
        XCTAssertNil(attachment.path)
    }
    
    func testInitWithDataAndContentType() {
        let attachment = Attachment(data: fixture.data, filename: fixture.filename, contentType: fixture.contentType)
    
        XCTAssertEqual(fixture.data, attachment.data)
        XCTAssertEqual(fixture.filename, attachment.filename)
        XCTAssertEqual(fixture.contentType, attachment.contentType)
        XCTAssertNil(attachment.path)
    }
    
    func testInitWithPath() {
        let attachment = Attachment(path: fixture.path)
    
        XCTAssertEqual(fixture.path, attachment.path)
        XCTAssertEqual(fixture.filename, attachment.filename)
        XCTAssertNil(attachment.contentType)
        XCTAssertNil(attachment.data)
    }
    
    func testInitWithEmptyPath() {
        let attachment = Attachment(path: "")
        
        XCTAssertEqual("", attachment.path)
        XCTAssertEqual("", attachment.filename)
        XCTAssertNil(attachment.contentType)
        XCTAssertNil(attachment.data)
    }
    
    func testInitWithPath_Filename() {
        let attachment = Attachment(path: fixture.filename)
    
        XCTAssertEqual(fixture.filename, attachment.path)
        XCTAssertEqual(fixture.filename, attachment.filename)
    }
    
    func testInitWithPath_FilenameWithSlash() {
        let path = "./\(fixture.filename)"
        let attachment = Attachment(path: path)
    
        XCTAssertEqual(path, attachment.path)
        XCTAssertEqual(fixture.filename, attachment.filename)
    }
    
    func testInitWithPath_PathIsADir() {
        let path = "a/dir//"
        let attachment = Attachment(path: path)
    
        XCTAssertEqual(path, attachment.path)
        XCTAssertEqual("dir", attachment.filename)
    }
    
    func testInitWithPathAndFilename() {
        let filename = "input.json"
        let attachment = Attachment(path: fixture.path, filename: filename)
    
        XCTAssertEqual(fixture.path, attachment.path)
        XCTAssertEqual(filename, attachment.filename)
        XCTAssertNil(attachment.contentType)
        XCTAssertNil(attachment.data)
    }
    
    func testInitWithPath_Filename_ContentType() {
        let attachment = Attachment(path: fixture.path, filename: fixture.filename, contentType: fixture.contentType)
        
        XCTAssertEqual(fixture.path, attachment.path)
        XCTAssertEqual(fixture.filename, attachment.filename)
        XCTAssertEqual(fixture.contentType, attachment.contentType)
    }
}
