@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import XCTest

/** Some of the test parameters are copied during debugging a working implementation. */
class SentryCrashStackEntryMapperTests: XCTestCase {

    private let bundleExecutable: String = "iOS-Swift"
    private var sut: SentryCrashStackEntryMapper!

    override func setUp() {
        super.setUp()
        sut = SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: [bundleExecutable]))
    }

    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }

    func testInstructionAddress() {
        let frame = sut.mapAddress(2_412_813_376)

        XCTAssertEqual("0x000000008fd09c40", frame.instructionAddress ?? "")
    }

    func testImageFromCache() {
        let image = createBinaryImage(2_488_998_912)
        let cache = SentryDependencyContainer.sharedInstance().binaryImageCache
        cache.start(false)
        cache.binaryImageAdded(image)

        let frame = sut.mapAddress(2_488_998_950)

        XCTAssertEqual("0x00000000945b1c00", frame.imageAddress ?? "")
        XCTAssertEqual("Expected Name at 2488998912", frame.package)

        cache.stop()
    }

    func testMapAddress_whenMainExecutableHasNoIncludes_shouldUseMainImageIdentity() {
        // -- Arrange --
        let processInfo = MockSentryProcessInfo()
        processInfo.overrides.processPath = "/opt/bin/cli"
        let provider = MapperBinaryImageProvider(images: [
            SentryBinaryImageInfo(name: "/opt/bin/cli", uuid: "main", vmAddress: 0, address: 100, size: 100)
        ])
        let cache = SentryBinaryImageCache(provider: provider, processInfoWrapper: processInfo)
        SentryDependencyContainer.sharedInstance().binaryImageCache = cache
        cache.start(false)
        defer { cache.stop() }
        let mapper = SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: []))

        // -- Act --
        let frame = mapper.mapAddress(150)

        // -- Assert --
#if SDK_V10
        XCTAssertEqual(frame.inApp, true)
#else
        XCTAssertEqual(frame.inApp, false)
#endif
        XCTAssertEqual(frame.package, "/opt/bin/cli")
    }

    func testMapAddress_whenAnotherImageHasSameFilename_shouldNotTreatItAsMainExecutable() {
        // -- Arrange --
        let (cache, _, _) = startCache(images: [
            SentryBinaryImageInfo(name: "/opt/bin/cli", uuid: "main", vmAddress: 0, address: 100, size: 100),
            SentryBinaryImageInfo(name: "/other/bin/cli", uuid: "other", vmAddress: 0, address: 300, size: 100)
        ])
        defer { cache.stop() }
        let mapper = SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: []))

        // -- Act --
        let frame = mapper.mapAddress(350)

        // -- Assert --
        XCTAssertEqual(frame.inApp, false)
        XCTAssertEqual(frame.package, "/other/bin/cli")
    }

    func testMapAddress_whenFrameworkMatchesIncludePrefix_shouldRemainInApp() {
        // -- Arrange --
        let (cache, _, _) = startCache(images: [
            SentryBinaryImageInfo(name: "/opt/bin/cli", uuid: "main", vmAddress: 0, address: 100, size: 100),
            SentryBinaryImageInfo(name: "/opt/lib/HelperKit", uuid: "helper", vmAddress: 0, address: 300, size: 100)
        ])
        defer { cache.stop() }
        let mapper = SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: ["helper"]))

        // -- Act --
        let frame = mapper.mapAddress(350)

        // -- Assert --
        XCTAssertEqual(frame.inApp, true)
    }

    func testMapAddress_whenMappingRepeatedly_shouldKeepMainImageResolvedAtCacheStart() {
        // -- Arrange --
        let (cache, processInfo, provider) = startCache(images: [
            SentryBinaryImageInfo(name: "/opt/bin/cli", uuid: "main", vmAddress: 0, address: 100, size: 100),
            SentryBinaryImageInfo(name: "/other/bin/cli", uuid: "other", vmAddress: 0, address: 300, size: 100)
        ])
        defer { cache.stop() }
        let mapper = SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: []))
        let refreshesAfterStart = provider.refreshInvocations
        processInfo.overrides.processPath = "/other/bin/cli"

        // -- Act --
        cache.start(false)
        let frames = (0..<10).map { _ in mapper.mapAddress(150) }
        let otherFrame = mapper.mapAddress(350)

        // -- Assert --
#if SDK_V10
        XCTAssertTrue(frames.allSatisfy { $0.inApp == true })
#else
        XCTAssertTrue(frames.allSatisfy { $0.inApp == false })
#endif
        XCTAssertEqual(otherFrame.inApp, false)
        XCTAssertEqual(provider.refreshInvocations, refreshesAfterStart)
    }

    func testMapAddress_whenCacheRestarts_shouldResolveMainImageAgain() {
        // -- Arrange --
        let (cache, processInfo, _) = startCache(images: [
            SentryBinaryImageInfo(name: "/opt/bin/cli", uuid: "main", vmAddress: 0, address: 100, size: 100),
            SentryBinaryImageInfo(name: "/other/bin/cli", uuid: "other", vmAddress: 0, address: 300, size: 100)
        ])
        defer { cache.stop() }
        let mapper = SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: []))

        // -- Act --
        cache.stop()
        processInfo.overrides.processPath = "/other/bin/cli"
        cache.start(false)

        // -- Assert --
        XCTAssertEqual(mapper.mapAddress(150).inApp, false)
#if SDK_V10
        XCTAssertEqual(mapper.mapAddress(350).inApp, true)
#else
        XCTAssertEqual(mapper.mapAddress(350).inApp, false)
#endif
    }

    func testMapAddress_whenImageIsMissing_shouldNotMatchMainImageAtZeroAddress() {
        // -- Arrange --
        let (cache, _, _) = startCache(images: [
            SentryBinaryImageInfo(name: "/opt/bin/cli", uuid: "main", vmAddress: 0, address: 0, size: 100)
        ])
        defer { cache.stop() }
        let mapper = SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: []))

        // -- Act --
        let frame = mapper.mapAddress(500)

        // -- Assert --
        XCTAssertEqual(frame.inApp, false)
        XCTAssertNil(frame.package)
    }

    func testInAppLogic_whenLiveMainImageIsKnown_shouldKeepReportClassificationPrefixBased() {
        // -- Arrange --
        let (cache, _, _) = startCache(images: [
            SentryBinaryImageInfo(name: "/opt/bin/cli", uuid: "main", vmAddress: 0, address: 100, size: 100)
        ])
        defer { cache.stop() }
        let reportInAppLogic = SentryInAppLogic(inAppIncludes: [])

        // -- Act --
        let isInApp = reportInAppLogic.is(inApp: "/opt/bin/cli")

        // -- Assert --
        XCTAssertFalse(isInApp)
    }

    private func startCache(images: [SentryBinaryImageInfo]) -> (SentryBinaryImageCache, MockSentryProcessInfo, MapperBinaryImageProvider) {
        let processInfo = MockSentryProcessInfo()
        processInfo.overrides.processPath = "/opt/bin/cli"
        let provider = MapperBinaryImageProvider(images: images)
        let cache = SentryBinaryImageCache(provider: provider, processInfoWrapper: processInfo)
        SentryDependencyContainer.sharedInstance().binaryImageCache = cache
        cache.start(false)
        return (cache, processInfo, provider)
    }

    private func createBinaryImage(_ address: UInt64) -> SentryBinaryImageInfo {
        SentryBinaryImageInfo(
            name: "Expected Name at \(address)",
            uuid: nil,
            vmAddress: 0,
            address: address,
            size: 100
        )
    }
}

private final class MapperBinaryImageProvider: SentryBinaryImageProvider {
    private let images: [SentryBinaryImageInfo]
    private weak var registry: (any SentryBinaryImageRegistry)?
    private(set) var refreshInvocations = 0

    init(images: [SentryBinaryImageInfo]) {
        self.images = images
    }

    func start(registry: any SentryBinaryImageRegistry) {
        self.registry = registry
    }

    func refresh() {
        refreshInvocations += 1
        guard let registry else { return }
        for image in images {
            registry.binaryImageAdded(image)
        }
    }

    func stop() {
        registry = nil
    }
}
