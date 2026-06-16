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
