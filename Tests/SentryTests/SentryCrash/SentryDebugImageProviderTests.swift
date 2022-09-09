@testable import Sentry
import XCTest

/**
 * Some of the test parameters are copied from debugging
 * SentryCrashReportConverter.convertDebugMeta.
 */
class SentryDebugImageProviderTests: XCTestCase {
    
    private class Fixture {
        func getSut(images: [SentryCrashBinaryImage] = []) -> SentryDebugImageProvider {
            let imageProvider = TestSentryCrashBinaryImageProvider()
            imageProvider.imageCount = images.count
            imageProvider.binaryImage = images
            return SentryDebugImageProvider(binaryImageProvider: imageProvider)
        }
        
        func getTestImages() -> [SentryCrashBinaryImage] {
            let imageName1 = "dyld_sim"
            let imageNameAsCharArray1 = SentryDebugImageProviderTests.stringToUIntCharArray(value: imageName1)
            let uuidAsCharArray1: [UInt8] = [132, 186, 235, 218, 173, 26, 51, 244, 179, 93, 138, 69, 245, 218, 243, 34]
            let image1 = SentryDebugImageProviderTests.createSentryCrashBinaryImage(
                address: 4_386_213_888,
                vmAddress: 140_734_563_811_328,
                size: 352_256,
                name: imageNameAsCharArray1,
                uuidAsCharArray: uuidAsCharArray1
            )
            
            let imageName2 = "UIKit"
            let imageNameAsCharArray2 = SentryDebugImageProviderTests.stringToUIntCharArray(value: imageName2)
            let uuidAsCharArray2: [UInt8] = [132, 186, 235, 218, 173, 26, 51, 244, 179, 93, 138, 69, 245, 218, 243, 34]
            let image2 = SentryDebugImageProviderTests.createSentryCrashBinaryImage(
                address: 5_386_213_888,
                vmAddress: 240_734_563_811_328,
                size: 1_352_256,
                name: imageNameAsCharArray2,
                uuidAsCharArray: uuidAsCharArray2
            )
            
            let imageName3 = "CoreData"
            let imageNameAsCharArray3 = SentryDebugImageProviderTests.stringToUIntCharArray(value: imageName3)
            let uuidAsCharArray3: [UInt8] = [132, 186, 235, 218, 173, 26, 51, 244, 179, 93, 138, 69, 245, 218, 243, 34]
            let image3 = SentryDebugImageProviderTests.createSentryCrashBinaryImage(
                address: 6_386_213_888,
                vmAddress: 340_734_563_811_328,
                size: 900_256,
                name: imageNameAsCharArray3,
                uuidAsCharArray: uuidAsCharArray3
            )
            
            return [image1, image2, image3]
        }
    }
    
    private let fixture = Fixture()
    
    func testThreeImages() {
        let sut = fixture.getSut(images: fixture.getTestImages())
        let actual = sut.getDebugImages()
        
        XCTAssertEqual(3, actual.count)
        
        XCTAssertEqual("dyld_sim", actual[0].name)
        XCTAssertEqual("UIKit", actual[1].name)
        XCTAssertEqual("CoreData", actual[2].name)
        
        let debugMeta = actual[0]
        XCTAssertEqual("84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322", debugMeta.uuid)
        XCTAssertEqual("0x0000000105705000", debugMeta.imageAddress)
        XCTAssertEqual("0x00007fff51af0000", debugMeta.imageVmAddress)
        XCTAssertEqual("apple", debugMeta.type)
        XCTAssertEqual(352_256, debugMeta.imageSize)
    }
    
    func testImageVmAddressIsZero() {
        let image = SentryDebugImageProviderTests.createSentryCrashBinaryImage(vmAddress: 0)
        
        let sut = fixture.getSut(images: [image])
        let actual = sut.getDebugImages()
        
        XCTAssertNil(actual[0].imageVmAddress)
    }
    
    func testImageSize() {
        func testWith(value: UInt64) {
            let image = SentryDebugImageProviderTests.createSentryCrashBinaryImage(size: value)
            let sut = fixture.getSut(images: [image])
            let actual = sut.getDebugImages()
            XCTAssertEqual(NSNumber(value: value), actual[0].imageSize)
        }
        
        testWith(value: 0)
        testWith(value: 1_000)
        testWith(value: UINT64_MAX)
    }
    
    func testImageAddress() {
        func testWith(value: UInt64, expected: String) {
            let image = SentryDebugImageProviderTests.createSentryCrashBinaryImage(address: value)
            let sut = fixture.getSut(images: [image])
            let actual = sut.getDebugImages()
            
            XCTAssertEqual(1, actual.count)
            
            let debugMeta = actual[0]
            XCTAssertEqual(expected, debugMeta.imageAddress)
        }
        
        testWith(value: UINT64_MAX, expected: "0xffffffffffffffff")
        testWith(value: 0, expected: "0x0000000000000000")
        testWith(value: 0, expected: "0x0000000000000000")
        testWith(value: 4_361_940_992, expected: "0x0000000103fdf000")
    }
    
    func testNoImages() {
        let actual = fixture.getSut().getDebugImages()
        
        XCTAssertEqual(0, actual.count)
    }
    
    func testImagesForThreads() {
        let sut = fixture.getSut(images: fixture.getTestImages())
        
        let thread = SentryThread(threadId: NSNumber(value: 1))
        let frame = Sentry.Frame()
        frame.imageAddress = "0x0000000105705000"
        thread.stacktrace = SentryStacktrace(frames: [frame], registers: [:])
        
        var actual = sut.getDebugImages(for: [thread])
        
        XCTAssertEqual(actual.count, 1)
        XCTAssertEqual(actual[0].name, "dyld_sim")
        XCTAssertEqual(actual[0].imageAddress, "0x0000000105705000")
        
        let frame2 = Sentry.Frame()
        frame2.imageAddress = "0x00000001410b1a00"
        let frame3 = Sentry.Frame()
        frame3.imageAddress = "0x000000017ca5e400"
        thread.stacktrace = SentryStacktrace(frames: [frame2, frame3], registers: [:])
        
        actual = sut.getDebugImages(for: [thread])
        
        XCTAssertEqual(actual.count, 2)
        XCTAssertEqual(actual[0].name, "UIKit")
        XCTAssertEqual(actual[0].imageAddress, "0x00000001410b1a00")
        
        XCTAssertEqual(actual[1].name, "CoreData")
        XCTAssertEqual(actual[1].imageAddress, "0x000000017ca5e400")
    }
    
    func test_NoImage_ForThread_WithoutStackTrace() {
        let sut = fixture.getSut(images: fixture.getTestImages())
        let thread = SentryThread(threadId: NSNumber(value: 1))
        let actual = sut.getDebugImages(for: [thread])
        
        XCTAssertEqual(actual.count, 0)
    }
        
    private static func createSentryCrashBinaryImage(
        address: UInt64 = 0,
        vmAddress: UInt64 = 0,
        size: UInt64 = 0,
        name: [CChar]? = nil,
        uuidAsCharArray: [UInt8]? = nil
    ) -> SentryCrashBinaryImage {
        
        var namePointer = UnsafeMutablePointer<CChar>(nil)
        if let nameNotNil = name {
            namePointer = UnsafeMutablePointer<CChar>.allocate(capacity: nameNotNil.count)
            namePointer?.initialize(from: nameNotNil, count: nameNotNil.count)
        }
        
        var uuidPointer = UnsafeMutablePointer<UInt8>(nil)
        if let uuidNotNil = uuidAsCharArray {
            uuidPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: uuidNotNil.count)
            uuidPointer?.initialize(from: uuidNotNil, count: uuidNotNil.count)
        }
        
        return SentryCrashBinaryImage(
            address: address,
            vmAddress: vmAddress,
            size: size,
            name: namePointer,
            uuid: uuidPointer,
            cpuType: 0,
            cpuSubType: 0,
            majorVersion: 0,
            minorVersion: 0,
            revisionVersion: 0,
            crashInfoMessage: nil,
            crashInfoMessage2: nil
        )
    }
    
    private static func stringToUIntCharArray(value: String) -> [CChar] {
        var buffer: [CChar] = Array(repeating: 0, count: value.utf8.count + 1)
        strcpy(&buffer, value)
        return buffer
    }
    
}
