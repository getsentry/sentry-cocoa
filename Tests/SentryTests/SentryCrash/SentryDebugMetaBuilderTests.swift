@testable import Sentry
import XCTest

/**
 * Some of the test parameters are copied from debugging
 * SentryCrashReportConverter.convertDebugMeta.
 */
class SentryDebugMetaBuilderTests: XCTestCase {
    
    private var imageProvider: TestSentryCrashBinaryImageProvider!
    private var sut: SentryDebugMetaBuilder!
    
    override func setUp() {
        super.setUp()
        
        imageProvider = TestSentryCrashBinaryImageProvider()
        sut = SentryDebugMetaBuilder(binaryImageProvider: imageProvider)
    }
    
    func testThreeImages() {
        let imageName = "dyld_sim"
        let imageNameAsCharArray = stringToUIntCharArray(value: imageName)
        let image = createSentryCrashBinaryImage(
            address: 4_386_213_888,
            vmAddress: 140_734_563_811_328,
            size: 352_256,
            name: imageNameAsCharArray
        )
        
        let actual = whenBuildDebugMetaWith(images: [image, image, image])
        
        XCTAssertEqual(3, actual.count)
        XCTAssertEqual(actual[0].name, actual[1].name)
        XCTAssertEqual(actual[1].name, actual[2].name)
        
        let debugMeta = actual[0]
        XCTAssertEqual(imageName, debugMeta.name)
        XCTAssertNil(debugMeta.uuid)
        XCTAssertEqual("0x0000000105705000", debugMeta.imageAddress)
        XCTAssertEqual("0x00007fff51af0000", debugMeta.imageVmAddress)
        XCTAssertEqual("apple", debugMeta.type)
        XCTAssertEqual(352_256, debugMeta.imageSize)
    }
    
    func testImageVmAddressIsZero() {
        let image = createSentryCrashBinaryImage(vmAddress: 0)
        
        let actual = whenBuildDebugMetaWith(images: [image])
        
        XCTAssertNil(actual[0].imageVmAddress)
    }
    
    func testImageSize() {
        func testWith(value: UInt64) {
            let image = createSentryCrashBinaryImage(size: value)
            let actual = whenBuildDebugMetaWith(images: [image])
            XCTAssertEqual(NSNumber(value: value), actual[0].imageSize)
        }
        
        testWith(value: 0)
        testWith(value: 1_000)
        testWith(value: UINT64_MAX)
    }
    
    func testImageAddress() {
        func testWith(value: UInt64, expected: String) {
            let image = createSentryCrashBinaryImage(address: value)
            let actual = whenBuildDebugMetaWith(images: [image])
            
            XCTAssertEqual(1, actual.count)
            
            let debugMeta = actual[0]
            XCTAssertEqual(expected, debugMeta.imageAddress)
        }
        
        testWith(value: UINT64_MAX, expected: "0xffffffffffffffff")
        testWith(value: 0, expected: "0x0000000000000000")
        testWith(value: 0, expected: "0x0000000000000000")
        testWith(value: 4_361_940_992, expected: "0x0000000103fdf000")
    }
    
    /**
     * The test parameters are copied from real values during debugging
     * SentryCrashReportConverter.convertDebugMeta. We know that
     * SentryCrashReportConverter is working properly.
     */
    func testUUID() {
        func testWith(uuid: String, uuidAsCharArray: [UInt8]) {
            XCTAssertEqual(16, uuidAsCharArray.count, "Length of uuidAsCharArray has to be 16")
            let image = createSentryCrashBinaryImage(uuidAsCharArray: uuidAsCharArray)
            
            let actual = whenBuildDebugMetaWith(images: [image])
            
            XCTAssertEqual(uuid, actual[0].uuid)
        }
        
        testWith(
            uuid: "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322",
            uuidAsCharArray: [132, 186, 235, 218, 173, 26, 51, 244, 179, 93, 138, 69, 245, 218, 243, 34]
        )
        
        testWith(
            uuid: "C6402B73-CE6B-3893-B8C4-FCA2DCBDFFF7",
            uuidAsCharArray: [198, 64, 43, 115, 206, 107, 56, 147, 184, 196, 252, 162, 220, 189, 255, 247]
        )
        
        testWith(
            uuid: "4E852D8F-9427-382C-ACF0-6C38654710D0",
            uuidAsCharArray: [78, 133, 45, 143, 148, 39, 56, 44, 172, 240, 108, 56, 101, 71, 16, 208]
        )
    }
    
    func testNoImages() {
        let actual = sut.buildDebugMeta()
        
        XCTAssertEqual(0, actual.count)
    }
    
    private func createSentryCrashBinaryImage(
        address: UInt64 = 0,
        vmAddress: UInt64 = 0,
        size: UInt64 = 0,
        name: [CChar]? = nil,
        uuidAsCharArray: [UInt8]? = nil
    ) -> SentryCrashBinaryImage {
        SentryCrashBinaryImage(
            address: address,
            vmAddress: vmAddress,
            size: size,
            name: name,
            uuid: uuidAsCharArray,
            cpuType: 0,
            cpuSubType: 0,
            majorVersion: 0,
            minorVersion: 0,
            revisionVersion: 0
        )
    }
    
    private func whenBuildDebugMetaWith(images: [SentryCrashBinaryImage]) -> [DebugMeta] {
        imageProvider.imageCount = images.count
        imageProvider.binaryImage = images
        return sut.buildDebugMeta()
    }
    
    private func stringToUIntCharArray(value: String) -> [CChar] {
        var buffer: [CChar] = Array(repeating: 0, count: value.utf8.count + 1)
        strcpy(&buffer, value)
        return buffer
    }
    
}
