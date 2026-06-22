@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryInternalDebugApiTests: XCTestCase {

    // MARK: - images

    func testImages_whenProviderHasImages_shouldReturnThem() {
        // -- Arrange --
        let image = DebugMeta()
        image.imageAddress = "0x0000000105705000"
        image.imageVmAddress = "0x0000000105705000"
        image.codeFile = "codeFile"
        image.debugID = "debugID"
        image.imageSize = 100
        image.type = "macho"

        let debugImageProvider = TestDebugImageProvider()
        debugImageProvider.debugImages = [image]

        let sut = SentryInternalDebugApi(provider: MockDebugProvider(
            debugImageProvider: debugImageProvider
        ))

        // -- Act --
        let images = sut.images

        // -- Assert --
        XCTAssertEqual(images.count, 1)
        let result = images[0]
        XCTAssertEqual(result.imageAddress, "0x0000000105705000")
        XCTAssertEqual(result.imageVmAddress, "0x0000000105705000")
        XCTAssertEqual(result.codeFile, "codeFile")
        XCTAssertEqual(result.debugID, "debugID")
        XCTAssertEqual(result.imageSize, 100)
        XCTAssertEqual(result.type, "macho")
    }

    func testImages_whenProviderHasNoImages_shouldReturnEmpty() {
        // -- Arrange --
        let debugImageProvider = TestDebugImageProvider()
        debugImageProvider.debugImages = []

        let sut = SentryInternalDebugApi(provider: MockDebugProvider(
            debugImageProvider: debugImageProvider
        ))

        // -- Act --
        let images = sut.images

        // -- Assert --
        XCTAssertTrue(images.isEmpty)
    }

    // MARK: - images(forAddresses:)

    func testImagesForAddresses_whenEmptyAddresses_shouldReturnEmpty() {
        // -- Arrange --
        let sut = SentryInternalDebugApi(provider: MockDebugProvider())

        // -- Act --
        let result = sut.images(forAddresses: [])

        // -- Assert --
        XCTAssertTrue(result.isEmpty)
    }

    func testImagesForAddresses_shouldPopulateRawAddresses() {
        // -- Arrange --
        let cache = SentryBinaryImageCache()
        cache.start(false)
        let uuid: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                             0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10]
        "TestImage".withCString { name in
            uuid.withUnsafeBufferPointer { uuidBuf in
                cache.binaryImageAdded(imageName: name, vmAddress: 0x100000000, address: 0x105705000, size: 0x1000, uuid: uuidBuf.baseAddress)
            }
        }

        let sut = SentryInternalDebugApi(provider: MockDebugProvider(
            binaryImageCache: cache
        ))

        // -- Act --
        let result = sut.images(forAddresses: [0x105705000])

        // -- Assert --
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].imageAddressRaw, 0x105705000)
        XCTAssertEqual(result[0].imageVmAddressRaw, 0x100000000)
        XCTAssertEqual(result[0].imageAddress, "0x0000000105705000")
        XCTAssertEqual(result[0].imageVmAddress, "0x0000000100000000")
    }

    func testImagesForAddresses_whenVmAddressIsZero_shouldSetRawToZero() {
        // -- Arrange --
        let cache = SentryBinaryImageCache()
        cache.start(false)
        let uuid: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                             0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10]
        "TestImage".withCString { name in
            uuid.withUnsafeBufferPointer { uuidBuf in
                cache.binaryImageAdded(imageName: name, vmAddress: 0, address: 0x105705000, size: 0x1000, uuid: uuidBuf.baseAddress)
            }
        }

        let sut = SentryInternalDebugApi(provider: MockDebugProvider(
            binaryImageCache: cache
        ))

        // -- Act --
        let result = sut.images(forAddresses: [0x105705000])

        // -- Assert --
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].imageAddressRaw, 0x105705000)
        XCTAssertEqual(result[0].imageVmAddressRaw, 0)
        XCTAssertNil(result[0].imageVmAddress)
    }

    func testImagesForAddresses_whenNoMatch_shouldReturnEmpty() {
        // -- Arrange --
        let sut = SentryInternalDebugApi(provider: MockDebugProvider())

        // -- Act --
        let result = sut.images(forAddresses: [0xDEAD])

        // -- Assert --
        XCTAssertTrue(result.isEmpty)
    }
}

// MARK: - Mock

private struct MockDebugProvider: DebugImageProvider, BinaryImageCacheProvider {
    var debugImageProvider: SentryDebugImageProvider
    var binaryImageCache: SentryBinaryImageCache

    init(
        debugImageProvider: SentryDebugImageProvider = SentryDebugImageProvider(),
        binaryImageCache: SentryBinaryImageCache = SentryBinaryImageCache()
    ) {
        self.debugImageProvider = debugImageProvider
        self.binaryImageCache = binaryImageCache
    }
}
