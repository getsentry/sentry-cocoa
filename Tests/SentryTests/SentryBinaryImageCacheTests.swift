@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

private final class WeakBinaryImageRegistry {
    weak var value: (any SentryBinaryImageRegistry)?
}

private final class TestBinaryImageProvider: SentryBinaryImageProvider {
    private struct State {
        let registry = WeakBinaryImageRegistry()
        var images: [SentryBinaryImageInfo] = []
        var startInvocations = 0
        var refreshInvocations = 0
        var stopInvocations = 0
    }

    private let state = SentryMutex(State())

    var images: [SentryBinaryImageInfo] {
        get { state.withLock { $0.images } }
        set { state.withLock { $0.images = newValue } }
    }

    var startInvocations: Int { state.withLock { $0.startInvocations } }
    var refreshInvocations: Int { state.withLock { $0.refreshInvocations } }
    var stopInvocations: Int { state.withLock { $0.stopInvocations } }

    func start(registry: SentryBinaryImageRegistry) {
        state.withLock {
            $0.registry.value = registry
            $0.startInvocations += 1
        }
    }

    func refresh() {
        let (registry, images) = state.withLock { state in
            state.refreshInvocations += 1
            return (state.registry.value, state.images)
        }
        guard let registry else { return }
        images.forEach { registry.binaryImageAdded($0) }
    }

    func stop() {
        state.withLock {
            $0.registry.value = nil
            $0.stopInvocations += 1
        }
    }

    func notifyAdded(_ image: SentryBinaryImageInfo) {
        state.withLock { $0.registry.value }?.binaryImageAdded(image)
    }

    func notifyRemoved(at address: UInt64) {
        state.withLock { $0.registry.value }?.binaryImageRemoved(at: address)
    }
}

final class SentryBinaryImageCacheTests: XCTestCase {
    private var provider: TestBinaryImageProvider!
    private var sut: SentryBinaryImageCache!

    override func setUp() {
        super.setUp()
        provider = TestBinaryImageProvider()
        sut = SentryBinaryImageCache(provider: provider)
        sut.start(false)
    }

    override func tearDown() {
        LoadValidator.checkForDuplicatedSDKCallback = nil
        sut.stop()
        sut = nil
        provider = nil
        super.tearDown()
    }

    func testStart_whenAlreadyStarted_shouldNotResetCache() throws {
        // -- Arrange --
        provider.notifyAdded(makeBinaryImage(address: 100))

        // -- Act --
        sut.start(true)

        // -- Assert --
        let cache = try XCTUnwrap(sut.cache)
        XCTAssertEqual(cache.count, 1)
        XCTAssertEqual(sut.imageByAddress(100)?.name, "Expected Name at 100")
        XCTAssertEqual(provider.startInvocations, 1)
    }

    func testStart_shouldRefreshProviderImages() throws {
        // -- Arrange --
        sut.stop()
        provider.images = [makeBinaryImage(address: 100)]

        // -- Act --
        sut.start(false)

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(sut.cache).count, 1)
        XCTAssertEqual(sut.imageByAddress(100)?.name, "Expected Name at 100")
    }

    func testStop_whenAlreadyStopped_shouldNotStopProviderAgain() {
        // -- Act --
        sut.stop()
        sut.stop()

        // -- Assert --
        XCTAssertEqual(provider.stopInvocations, 1)
    }

    func testGetAllBinaryImages_shouldRefreshProvider() {
        // -- Arrange --
        let refreshCount = provider.refreshInvocations
        provider.images = [makeBinaryImage(address: 100)]

        // -- Act --
        let images = sut.getAllBinaryImages()

        // -- Assert --
        XCTAssertEqual(provider.refreshInvocations, refreshCount + 1)
        XCTAssertEqual(images.count, 1)
    }

    func testImageByAddress_whenImageIsMissing_shouldRefreshProvider() {
        // -- Arrange --
        provider.images = [makeBinaryImage(address: 100)]

        // -- Act --
        let image = sut.imageByAddress(150)

        // -- Assert --
        XCTAssertEqual(image?.name, "Expected Name at 100")
    }

    func testRefresh_whenProviderReturnsExistingImages_shouldDeduplicateByAddress() throws {
        // -- Arrange --
        provider.images = [makeBinaryImage(address: 100)]

        // -- Act --
        _ = sut.getAllBinaryImages()
        _ = sut.getAllBinaryImages()

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(sut.cache).count, 1)
    }

    func testBinaryImageAdded_whenDebugEnabled_shouldValidateDuplicatedSDK() throws {
        // -- Arrange --
        sut.stop()
        sut.start(true)
        let invocations = Invocations<(imageName: String, imageAddress: UInt64, imageSize: UInt64)>()
        LoadValidator.checkForDuplicatedSDKCallback = { imageName, imageAddress, imageSize in
            invocations.record((imageName, imageAddress, imageSize))
        }

        // -- Act --
        provider.notifyAdded(makeBinaryImage(address: 100, name: "/usr/lib/system.dylib"))

        // -- Assert --
        XCTAssertEqual(invocations.count, 1)
        let invocation = try XCTUnwrap(invocations.first)
        XCTAssertEqual(invocation.imageName, "/usr/lib/system.dylib")
        XCTAssertEqual(invocation.imageAddress, 100)
        XCTAssertEqual(invocation.imageSize, 100)
    }

    func testBinaryImageAdded_whenDebugDisabled_shouldNotValidateDuplicatedSDK() throws {
        // -- Arrange --
        let invocations = Invocations<Void>()
        LoadValidator.checkForDuplicatedSDKCallback = { _, _, _ in invocations.record(()) }

        // -- Act --
        provider.notifyAdded(makeBinaryImage(address: 100, name: "/usr/lib/system.dylib"))

        // -- Assert --
        XCTAssertEqual(invocations.count, 0)
        XCTAssertEqual(try XCTUnwrap(sut.cache).count, 1)
    }

    func testBinaryImageAdded_shouldKeepImagesSorted() throws {
        // -- Act --
        provider.notifyAdded(makeBinaryImage(address: 100))
        provider.notifyAdded(makeBinaryImage(address: 400))
        provider.notifyAdded(makeBinaryImage(address: 200))
        provider.notifyAdded(makeBinaryImage(address: 0))

        // -- Assert --
        let cache = try XCTUnwrap(sut.cache)
        XCTAssertEqual(cache.map(\.address), [0, 100, 200, 400])
    }

    func testBinaryImageAdded_shouldConvertUUIDWithoutSentryCrash() {
        // -- Arrange --
        let uuid: [UInt8] = [
            132, 186, 235, 218, 173, 26, 51, 244,
            179, 93, 138, 69, 245, 218, 243, 34
        ]

        // -- Act --
        "image".withCString { name in
            uuid.withUnsafeBufferPointer { uuidBuffer in
                sut.binaryImageAdded(
                    imageName: name,
                    vmAddress: 100,
                    address: 100,
                    size: 100,
                    uuid: uuidBuffer.baseAddress
                )
            }
        }

        // -- Assert --
        XCTAssertEqual(sut.imageByAddress(100)?.uuid, "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322")
    }

    func testBinaryImageAdded_whenNameIsNil_shouldIgnoreImage() throws {
        // -- Act --
        sut.binaryImageAdded(imageName: nil, vmAddress: 100, address: 100, size: 100, uuid: nil)

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(sut.cache).count, 0)
    }

    func testBinaryImageAdded_whenNameIsNotUTF8_shouldIgnoreImage() throws {
        // -- Arrange --
        let invalidUTF8: [CChar] = [-1, 0]

        // -- Act --
        invalidUTF8.withUnsafeBufferPointer { name in
            sut.binaryImageAdded(
                imageName: name.baseAddress,
                vmAddress: 100,
                address: 100,
                size: 100,
                uuid: nil
            )
        }

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(sut.cache).count, 0)
    }

    func testBinaryImageRemoved_shouldRemoveImageStartingAtAddress() throws {
        // -- Arrange --
        provider.notifyAdded(makeBinaryImage(address: 100))
        provider.notifyAdded(makeBinaryImage(address: 200))

        // -- Act --
        provider.notifyRemoved(at: 100)

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(sut.cache).map(\.address), [200])
        XCTAssertNil(sut.imageByAddress(100))
    }

    func testBinaryImageRemoved_whenAddressIsUnknown_shouldKeepImages() throws {
        // -- Arrange --
        provider.notifyAdded(makeBinaryImage(address: 100))

        // -- Act --
        provider.notifyRemoved(at: 1_000_000)

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(sut.cache).count, 1)
    }

    func testImageByAddress_shouldFindContainingImage() {
        // -- Arrange --
        provider.notifyAdded(makeBinaryImage(address: 0))
        provider.notifyAdded(makeBinaryImage(address: 100))
        provider.notifyAdded(makeBinaryImage(address: 200))
        provider.notifyAdded(makeBinaryImage(address: 400))

        // -- Assert --
        XCTAssertEqual(sut.imageByAddress(150)?.address, 100)
        XCTAssertEqual(sut.imageByAddress(0)?.address, 0)
        XCTAssertEqual(sut.imageByAddress(99)?.address, 0)
        XCTAssertEqual(sut.imageByAddress(200)?.address, 200)
        XCTAssertEqual(sut.imageByAddress(299)?.address, 200)
        XCTAssertEqual(sut.imageByAddress(400)?.address, 400)
        XCTAssertNil(sut.imageByAddress(300))
        XCTAssertNil(sut.imageByAddress(399))
    }

    func testAddingImagesWhileStoppingAndStartingOnDifferentThreads_shouldNotCrash() {
        // -- Arrange --
        let count = 500
        let expectation = expectation(description: "Add images")
        expectation.expectedFulfillmentCount = count

        // -- Act --
        for index in 0..<count {
            DispatchQueue.global().async {
                self.sut.binaryImageAdded(makeBinaryImage(address: UInt64(index * 10)))
                self.sut.stop()
                self.sut.start(false)
                expectation.fulfill()
            }
        }

        // -- Assert --
        waitForExpectations(timeout: 10)
    }

    func testAddingImagesWhileReadingOnDifferentThreads_shouldNotCrash() {
        // -- Arrange --
        let count = 500
        let expectation = expectation(description: "Read images")
        expectation.expectedFulfillmentCount = count

        // -- Act --
        for index in 0..<count {
            DispatchQueue.global().async {
                self.sut.binaryImageAdded(makeBinaryImage(address: UInt64(index * 10), name: "image"))
                _ = self.sut.getAllBinaryImages()
                expectation.fulfill()
            }
        }

        // -- Assert --
        waitForExpectations(timeout: 10)
    }
}

private func makeBinaryImage(
    address: UInt64,
    vmAddress: UInt64 = 0,
    name: String? = nil,
    size: UInt64 = 100
) -> SentryBinaryImageInfo {
    SentryBinaryImageInfo(
        name: name ?? "Expected Name at \(address)",
        uuid: "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322",
        vmAddress: vmAddress,
        address: address,
        size: size
    )
}
