import XCTest

class SentryNSURLSessionTaskSearchTests: XCTestCase {

    // We need to know whether Apple changes the NSURLSessionTask implementation.
     func test_URLSessionTask_ByIosVersion() {
        let classes = SentryNSURLSessionTaskSearch.urlSessionTaskClassesToTrack()
        
        XCTAssertEqual(classes.count, 1)
        if #available(iOS 14, tvOS 14, *) {
            XCTAssertTrue(classes.first === URLSessionTask.self)
        } else {
            XCTAssertEqual(String(describing: classes.first!), "__NSCFURLSessionTask")
        }
    }

}
