@testable import Sentry
import XCTest

/** The tests are basically a duplication of the implementation of the actual class.
 * We still want to test it like this because you have to mess up the code in two
 * different places to break it.
 */
class SentryCrashDefaultBinaryImageProviderTests: XCTestCase {
    
    private class Fixture {
        func getSut() -> SentryCrashDefaultBinaryImageProvider {
            SentryCrashDefaultBinaryImageProvider()
        }
    }

    private let fixture = Fixture()

    func testImageCount() {
        XCTAssertEqual(sentrycrashdl_imageCount(), Int32(fixture.getSut().getImageCount()))
    }

    func testGetImages() {
        let sut = fixture.getSut()
        let imageCount = sut.getImageCount()
        for i in 0 ... imageCount {
            let actual = sut.getBinaryImage(i, isCrash: true)
            
            var expected = SentryCrashBinaryImage()
            sentrycrashdl_getBinaryImage(Int32(i), &expected, /*isCrash*/ false)
            
            XCTAssertEqual(expected.uuid, actual.uuid)
            XCTAssertEqual(expected.vmAddress, actual.vmAddress)
            XCTAssertEqual(expected.address, actual.address)
            XCTAssertEqual(expected.size, actual.size)
            XCTAssertEqual(expected.name, actual.name)
        }
    }
}
