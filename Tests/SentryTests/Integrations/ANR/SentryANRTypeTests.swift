@testable import Sentry
import XCTest

final class SentryANRTypeTests: XCTestCase {

   func testExceptionType_FatalFullyBlocking() {
      XCTAssertEqual(
         "Fatal App Hang Fully Blocked",
         SentryAppHangTypeMapper.getExceptionType(anrType: .fatalFullyBlocking)
      )
   }
   
   func testExceptionType_FatalNonFullyBlocking() {
      XCTAssertEqual(
         "Fatal App Hang Non Fully Blocked", 
         SentryAppHangTypeMapper.getExceptionType(anrType: .fatalNonFullyBlocking)
      )
   }
   
   func testExceptionType_FullyBlocking() {
      XCTAssertEqual(
         "App Hang Fully Blocked",
         SentryAppHangTypeMapper.getExceptionType(anrType: .fullyBlocking)
      )
   }
   
   func testExceptionType_NonFullyBlocking() {
      XCTAssertEqual(
         "App Hang Non Fully Blocked",
         SentryAppHangTypeMapper.getExceptionType(anrType: .nonFullyBlocking)
      )
   }
   
   func testExceptionType_Unknown() {
      XCTAssertEqual(
         "App Hanging",
         SentryAppHangTypeMapper.getExceptionType(anrType: .unknown)
      )
   }
   
   func testIsExceptionTypeAppHang_FatalFullyBlocking() {
      XCTAssertTrue(
         SentryAppHangTypeMapper.isExceptionTypeAppHang(exceptionType: "Fatal App Hang Fully Blocked")
      )
   }
   
   func testIsExceptionTypeAppHang_FatalNonFullyBlocking() {
      XCTAssertTrue(
         SentryAppHangTypeMapper.isExceptionTypeAppHang(exceptionType: "Fatal App Hang Non Fully Blocked")
      )
   }
   
   func testIsExceptionTypeAppHang_FullyBlocking() {
      XCTAssertTrue(
         SentryAppHangTypeMapper.isExceptionTypeAppHang(exceptionType: "App Hang Fully Blocked")
      )
   }
   
   func testIsExceptionTypeAppHang_NonFullyBlocking() {
      XCTAssertTrue(
         SentryAppHangTypeMapper.isExceptionTypeAppHang(exceptionType: "App Hang Non Fully Blocked")
      )
   }
   
   func testIsExceptionTypeAppHang_AppHanging() {
      XCTAssertTrue(
         SentryAppHangTypeMapper.isExceptionTypeAppHang(exceptionType: "App Hanging")
      )
   }
   
   func testIsExceptionTypeAppHang_Unknown() {
      XCTAssertFalse(
         SentryAppHangTypeMapper.isExceptionTypeAppHang(exceptionType: "Unknown")
      )
   }
    
    func testGetFatalExceptionType_NonFullyBlocking() {
        XCTAssertEqual(
            "Fatal App Hang Non Fully Blocked",
            SentryAppHangTypeMapper.getFatalExceptionType(nonFatalErrorType: "App Hang Non Fully Blocked")
        )
    }
    
    func testGetFatalExceptionType_FullyBlocking() {
        XCTAssertEqual(
            "Fatal App Hang Fully Blocked",
            SentryAppHangTypeMapper.getFatalExceptionType(nonFatalErrorType: "App Hang Fully Blocked")
        )
    }
    
    func testGetFatalExceptionType_FullyBlockingIsDefault() {
        XCTAssertEqual(
            "Fatal App Hang Fully Blocked",
            SentryAppHangTypeMapper.getFatalExceptionType(nonFatalErrorType: "")
        )
    }

}
