@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

/** Some of the test parameters are copied during debbuging a working implementation.
 */
class SentryCrashStackEntryMapperTests: XCTestCase {
    
    private let bundleExecutable: String = "iOS-Swift"
    private var sut: SentryCrashStackEntryMapper!
    
    override func setUp() {
        super.setUp()
        sut = SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: [bundleExecutable]))
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testInstructionAddress() {
        var cursor = SentryCrashStackCursor()
        cursor.stackEntry.address = 2_412_813_376
        
        let frame = sut.mapStackEntry(with: cursor)
        
        XCTAssertEqual("0x000000008fd09c40", frame.instructionAddress ?? "")
    }

    func testImageFromCache() {
        let image = createCrashBinaryImage(2_488_998_912)
        SentryDependencyContainer.sharedInstance().binaryImageCache.start(false)
        SentryDependencyContainer.sharedInstance().binaryImageCache.binaryImageAdded(imageName: image.name,
                                                                                     vmAddress: image.vmAddress,
                                                                                     address: image.address,
                                                                                     size: image.size,
                                                                                     uuid: image.uuid)

        var cursor = SentryCrashStackCursor()
        cursor.stackEntry.address = 2_488_998_950

        let frame = sut.mapStackEntry(with: cursor)

        XCTAssertEqual("0x00000000945b1c00", frame.imageAddress ?? "")
        XCTAssertEqual("Expected Name at 2488998912", frame.package)

        SentryDependencyContainer.sharedInstance().binaryImageCache.stop()
    }

    private func createCrashBinaryImage(_ address: UInt) -> SentryCrashBinaryImage {
        let name = "Expected Name at \(address)"
        let nameCString = name.withCString { strdup($0) }

        let binaryImage = SentryCrashBinaryImage(
            address: UInt64(address),
            vmAddress: 0,
            size: 100,
            name: nameCString,
            uuid: nil,
            cpuType: 1,
            cpuSubType: 1,
            crashInfoMessage: nil,
            crashInfoMessage2: nil
        )

        return binaryImage
    }
}
