@testable import Sentry
import XCTest

/**
 * Some of the test parameters are copied from debugging
 * SentryCrashReportConverter.convertDebugMeta.
 */
class SentryDebugImageProviderTests: XCTestCase {
    
    private class Fixture {
        
        let cache: SentryBinaryImageCache
        
        init() {
            cache = SentryBinaryImageCache()
        }
        
        func getSut(images: [SentryCrashBinaryImage] = []) -> SentryDebugImageProvider {
            let imageProvider = TestSentryCrashBinaryImageProvider()
            imageProvider.imageCount = images.count
            imageProvider.binaryImage = images
            
            cache.start()
            for image in images {
                var i = image
                cache.binaryImageAdded(&i)
            }
            
            return SentryDebugImageProvider(binaryImageProvider: imageProvider, binaryImageCache: cache)
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
    
    override func tearDown() {
        fixture.cache.stop()
        super.tearDown()
    }
    
    @available(*, deprecated)
    func testThreeImages() throws {
        let sut = fixture.getSut(images: fixture.getTestImages())
        let actual = sut.getDebugImagesCrashed(false)
        
        XCTAssertEqual(3, actual.count)
        
        XCTAssertEqual("dyld_sim", try XCTUnwrap(actual.first).codeFile)
        XCTAssertEqual("UIKit", try XCTUnwrap(actual.element(at: 1)).codeFile)
        XCTAssertEqual("CoreData", try XCTUnwrap(actual.element(at: 2)).codeFile)
        
        let debugMeta = try XCTUnwrap(actual.first)
        XCTAssertEqual("84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322", debugMeta.debugID)
        XCTAssertEqual("0x0000000105705000", debugMeta.imageAddress)
        XCTAssertEqual("0x00007fff51af0000", debugMeta.imageVmAddress)
        XCTAssertEqual("macho", debugMeta.type)
        XCTAssertEqual(352_256, debugMeta.imageSize)
    }
    
    @available(*, deprecated)
    func testImageVmAddressIsZero() {
        let image = SentryDebugImageProviderTests.createSentryCrashBinaryImage(vmAddress: 0)
        
        let sut = fixture.getSut(images: [image])
        let actual = sut.getDebugImagesCrashed(false)
        
        XCTAssertNil(try XCTUnwrap(actual.first).imageVmAddress)
    }
    
    @available(*, deprecated)
    func testImageSize() {
        func testWith(value: UInt64) {
            let image = SentryDebugImageProviderTests.createSentryCrashBinaryImage(size: value)
            let sut = fixture.getSut(images: [image])
            let actual = sut.getDebugImagesCrashed(false)
            XCTAssertEqual(NSNumber(value: value), try XCTUnwrap(actual.first).imageSize)
        }
        
        testWith(value: 0)
        testWith(value: 1_000)
        testWith(value: UINT64_MAX)
    }
    
    @available(*, deprecated)
    func testImageAddress() throws {
        func testWith(value: UInt64, expected: String) throws {
            let image = SentryDebugImageProviderTests.createSentryCrashBinaryImage(address: value)
            let sut = fixture.getSut(images: [image])
            let actual = sut.getDebugImagesCrashed(false)
            
            XCTAssertEqual(1, actual.count)
            
            let debugMeta = try XCTUnwrap(actual.first)
            XCTAssertEqual(expected, debugMeta.imageAddress)
        }
        
        try testWith(value: UINT64_MAX, expected: "0xffffffffffffffff")
        try testWith(value: 0, expected: "0x0000000000000000")
        try testWith(value: 0, expected: "0x0000000000000000")
        try testWith(value: 4_361_940_992, expected: "0x0000000103fdf000")
    }
    
    @available(*, deprecated)
    func testNoImages() {
        let actual = fixture.getSut().getDebugImagesCrashed(false)
        
        XCTAssertEqual(0, actual.count)
    }
    
    @available(*, deprecated)
    func testImagesForThreads() {
        let sut = fixture.getSut(images: fixture.getTestImages())
        
        let thread = SentryThread(threadId: NSNumber(value: 1))
        let frame = Sentry.Frame()
        frame.imageAddress = "0x0000000105705000"
        thread.stacktrace = SentryStacktrace(frames: [frame], registers: [:])
        
        var actual = sut.getDebugImages(for: [thread], isCrash: false)
        
        XCTAssertEqual(actual.count, 1)
        XCTAssertEqual(try XCTUnwrap(actual.first).codeFile, "dyld_sim")
        XCTAssertEqual(try XCTUnwrap(actual.first).imageAddress, "0x0000000105705000")
        
        let frame2 = Sentry.Frame()
        frame2.imageAddress = "0x00000001410b1a00"
        let frame3 = Sentry.Frame()
        frame3.imageAddress = "0x000000017ca5e400"
        thread.stacktrace = SentryStacktrace(frames: [frame2, frame3], registers: [:])
        
        actual = sut.getDebugImages(for: [thread], isCrash: false)
        
        XCTAssertEqual(actual.count, 2)
        XCTAssertEqual(try XCTUnwrap(actual.first).codeFile, "UIKit")
        XCTAssertEqual(try XCTUnwrap(actual.first).imageAddress, "0x00000001410b1a00")
        
        XCTAssertEqual(try XCTUnwrap(actual.element(at: 1)).codeFile, "CoreData")
        XCTAssertEqual(try XCTUnwrap(actual.element(at: 1)).imageAddress, "0x000000017ca5e400")
    }
    
    @available(*, deprecated)
    func test_NoImage_ForThread_WithoutStackTrace() {
        let sut = fixture.getSut(images: fixture.getTestImages())
        let thread = SentryThread(threadId: NSNumber(value: 1))
        let actual = sut.getDebugImages(for: [thread], isCrash: false)
        
        XCTAssertEqual(actual.count, 0)
    }
    
    func testGetDebugImagesFromCacheForThreads() throws {
        let sut = fixture.getSut(images: fixture.getTestImages())
        
        let frame1 = Sentry.Frame()
        frame1.imageAddress = "0x0000000105705000"
        
        let frame2 = Sentry.Frame()
        frame2.imageAddress = "0x00000001410b1a00"
        
        let thread1 = SentryThread(threadId: NSNumber(value: 1))
        thread1.stacktrace = SentryStacktrace(frames: [frame1, frame2], registers: [:])
        
        let thread2 = SentryThread(threadId: NSNumber(value: 2))
        thread2.stacktrace = SentryStacktrace(frames: [frame2], registers: [:])
        
        let actual = sut.getDebugImagesFromCacheForThreads(threads: [thread1, thread2])
        
        XCTAssertEqual(actual.count, 2)
        let image1 = try XCTUnwrap(actual.first)
        
        XCTAssertEqual(image1.debugID, "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322")
        XCTAssertEqual(image1.type, SentryDebugImageType)
        XCTAssertEqual(image1.imageVmAddress, "0x0000daf262294000")
        XCTAssertEqual(image1.imageAddress, "0x00000001410b1a00")
        XCTAssertEqual(image1.imageSize, 1_352_256)
        XCTAssertEqual(image1.codeFile, "UIKit")
        
        let image2 = try XCTUnwrap(actual.last)
        
        XCTAssertEqual(image2.debugID, "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322")
        XCTAssertEqual(image2.type, SentryDebugImageType)
        XCTAssertEqual(image2.imageVmAddress, "0x00007fff51af0000")
        XCTAssertEqual(image2.imageAddress, "0x0000000105705000")
        XCTAssertEqual(image2.imageSize, 352_256)
        XCTAssertEqual(image2.codeFile, "dyld_sim")
    }
    
    func testGetDebugImagesFromCacheForFrames() throws {
        let sut = fixture.getSut(images: fixture.getTestImages())
        
        let frame1 = Sentry.Frame()
        frame1.imageAddress = "0x0000000105705000"
        
        let frame2 = Sentry.Frame()
        frame2.imageAddress = "0x00000001410b1a00"
        
        let actual = sut.getDebugImagesFromCacheForFrames(frames: [frame1, frame2])
        
        XCTAssertEqual(actual.count, 2)
        let image1 = try XCTUnwrap(actual.first)
        
        XCTAssertEqual(image1.debugID, "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322")
        XCTAssertEqual(image1.type, SentryDebugImageType)
        XCTAssertEqual(image1.imageVmAddress, "0x0000daf262294000")
        XCTAssertEqual(image1.imageAddress, "0x00000001410b1a00")
        XCTAssertEqual(image1.imageSize, 1_352_256)
        XCTAssertEqual(image1.codeFile, "UIKit")
        
        let image2 = try XCTUnwrap(actual.last)
        
        XCTAssertEqual(image2.debugID, "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322")
        XCTAssertEqual(image2.type, SentryDebugImageType)
        XCTAssertEqual(image2.imageVmAddress, "0x00007fff51af0000")
        XCTAssertEqual(image2.imageAddress, "0x0000000105705000")
        XCTAssertEqual(image2.imageSize, 352_256)
        XCTAssertEqual(image2.codeFile, "dyld_sim")
    }
    
    func testGetDebugImagesFromCacheForFrames_GarbageImageAddress() throws {
        let sut = fixture.getSut(images: fixture.getTestImages())
        
        let frame1 = Sentry.Frame()
        frame1.imageAddress = "0x0000000105705000"
        
        let frame2 = Sentry.Frame()
        frame2.imageAddress = "garbage"
        
        let actual = sut.getDebugImagesFromCacheForFrames(frames: [frame1, frame2])
        
        XCTAssertEqual(actual.count, 1)
        let image = try XCTUnwrap(actual.first)
        XCTAssertEqual(image.debugID, "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322")
        XCTAssertEqual(image.type, SentryDebugImageType)
        XCTAssertEqual(image.imageVmAddress, "0x00007fff51af0000")
        XCTAssertEqual(image.imageAddress, "0x0000000105705000")
        XCTAssertEqual(image.imageSize, 352_256)
        XCTAssertEqual(image.codeFile, "dyld_sim")
    }
    
    func testGetDebugImagesFromCacheForThreads_EmptyArray() throws {
        let sut = fixture.getSut(images: fixture.getTestImages())
        
        let actual = sut.getDebugImagesFromCacheForThreads(threads: [])
        
        XCTAssertEqual(actual.count, 0)
    }
    
    func testGetDebugImagesForImageAddressesFromCache() throws {
        let sut = fixture.getSut(images: fixture.getTestImages())
        
        let imageAddress = "0x00000001410b1a00"
        
        let actual = sut.getDebugImagesForImageAddressesFromCache(imageAddresses: [imageAddress])
        
        XCTAssertEqual(actual.count, 1)
        let image = try XCTUnwrap(actual.first)
        
        XCTAssertEqual(image.debugID, "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322")
        XCTAssertEqual(image.type, SentryDebugImageType)
        XCTAssertEqual(image.imageVmAddress, "0x0000daf262294000")
        XCTAssertEqual(image.imageAddress, "0x00000001410b1a00")
        XCTAssertEqual(image.imageSize, 1_352_256)
        XCTAssertEqual(image.codeFile, "UIKit")
    }
    
    func testGetDebugImagesForImageAddressesFromCache_GarbageImageAddress() throws {
        let sut = fixture.getSut(images: fixture.getTestImages())
        
        let imageAddress = "garbage"
        
        let actual = sut.getDebugImagesForImageAddressesFromCache(imageAddresses: [imageAddress])

        XCTAssertEqual(actual.count, 0)
    }
    
    func testGetDebugImagesForImageAddressesFromCache_EmptyArray() throws {
        let sut = fixture.getSut(images: fixture.getTestImages())
        
        let actual = sut.getDebugImagesForImageAddressesFromCache(imageAddresses: [])
        
        XCTAssertEqual(actual.count, 0)
    }
    
    func testGetDebugImagesFromCache() throws {
        let sut = fixture.getSut(images: fixture.getTestImages())
        
        let actual = sut.getDebugImagesFromCache()
        
        XCTAssertEqual(actual.count, 3)
        
        let coreDataImage = try XCTUnwrap(actual.first { $0.codeFile == "CoreData" })

        XCTAssertEqual(coreDataImage.debugID, "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322")
        XCTAssertEqual(coreDataImage.type, SentryDebugImageType)
        XCTAssertEqual(coreDataImage.imageVmAddress, "0x000135e572a38000")
        XCTAssertEqual(coreDataImage.imageAddress, "0x000000017ca5e400")
        XCTAssertEqual(coreDataImage.imageSize, 900_256)
        XCTAssertEqual(coreDataImage.codeFile, "CoreData")
        
        let uiKitImage = try XCTUnwrap(actual.first { $0.codeFile == "UIKit" })
        
        XCTAssertEqual(uiKitImage.debugID, "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322")
        XCTAssertEqual(uiKitImage.type, SentryDebugImageType)
        XCTAssertEqual(uiKitImage.imageVmAddress, "0x0000daf262294000")
        XCTAssertEqual(uiKitImage.imageAddress, "0x00000001410b1a00")
        XCTAssertEqual(uiKitImage.imageSize, 1_352_256)
        XCTAssertEqual(uiKitImage.codeFile, "UIKit")
        
        let dyldImage = try XCTUnwrap(actual.first { $0.codeFile == "dyld_sim" })
        
        XCTAssertEqual(dyldImage.debugID, "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322")
        XCTAssertEqual(dyldImage.type, SentryDebugImageType)
        XCTAssertEqual(dyldImage.imageVmAddress, "0x00007fff51af0000")
        XCTAssertEqual(dyldImage.imageAddress, "0x0000000105705000")
        XCTAssertEqual(dyldImage.imageSize, 352_256)
        XCTAssertEqual(dyldImage.codeFile, "dyld_sim")
    }
    
    func testGetDebugImagesFromCache_NoImages() {
        let sut = fixture.getSut(images: [])
        
        let actual = sut.getDebugImagesFromCache()
        
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
