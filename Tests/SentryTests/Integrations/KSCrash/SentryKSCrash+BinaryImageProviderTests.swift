#if SDK_V10
#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
#if !SWIFT_PACKAGE || SENTRY_PACKAGE_TEST_FIXTURES
internal import KSCrashRecordingCore
#endif
import Darwin
import MachO
import XCTest

final class SentryKSCrashBinaryImageProviderTests: XCTestCase {
    private var sut: SentryBinaryImageCache!

    override func setUp() {
        super.setUp()
        sut = SentryBinaryImageCache(provider: SentryKSCrash.BinaryImageProvider(), processInfoWrapper: ProcessInfo.processInfo)
    }

    override func tearDown() {
        sut.stop()
        sut = nil
        super.tearDown()
    }

    func testStart_shouldPublishKSCrashBinaryImages() throws {
        // -- Act --
        sut.start(false)

        // -- Assert --
        let images = try XCTUnwrap(sut.cache)
        XCTAssertFalse(images.isEmpty)
        XCTAssertTrue(images.allSatisfy { !$0.name.isEmpty })
        XCTAssertTrue(images.allSatisfy { $0.address > 0 })
    }

    func testStart_shouldIncludeDyld() throws {
        // -- Act --
        sut.start(false)

        // -- Assert --
        let images = try XCTUnwrap(sut.cache)
        XCTAssertTrue(images.contains { $0.name == "/usr/lib/dyld" })
    }

    func testRefresh_shouldNotDuplicateImages() throws {
        // -- Arrange --
        sut.start(false)
        let initialImages = try XCTUnwrap(sut.cache)

        // -- Act --
        let refreshedImages = sut.getAllBinaryImages()

        // -- Assert --
        XCTAssertEqual(refreshedImages.count, initialImages.count)
        XCTAssertEqual(Set(refreshedImages.map(\.address)).count, refreshedImages.count)
    }

    func testImageByAddress_shouldFindKSCrashImage() throws {
        // -- Arrange --
        sut.start(false)
        let image = try XCTUnwrap(sut.cache?.first)

        // -- Act --
        let result = sut.imageByAddress(image.address)

        // -- Assert --
        XCTAssertEqual(result?.address, image.address)
    }

#if !SWIFT_PACKAGE || SENTRY_PACKAGE_TEST_FIXTURES
    // Both test routes embed this pure-C framework without linking it at launch.
    // A real dyld unload between header acquisition and metadata extraction must not crash.
    // publish() consults the registry after taking the header pointer and before extracting, so the
    // registry closes the last reference there: the unload is real, only its timing is controlled.
    func testRefresh_whenImageUnloadsBeforeExtraction_shouldNotCrash() throws {
        // -- Arrange --
        let frameworks = try XCTUnwrap(Bundle(for: Self.self).privateFrameworksURL)
        let library = frameworks.appendingPathComponent("SentryUnloadingImage.framework/SentryUnloadingImage")
        for index in 0..<_dyld_image_count() {
            guard let name = _dyld_get_image_name(index) else { continue }
            guard !String(cString: name).hasSuffix("/SentryUnloadingImage.framework/SentryUnloadingImage") else {
                XCTFail("Invalid test setup: SentryUnloadingImage must be embedded but not linked or already loaded. dlopen must acquire its only reference")
                return
            }
        }
        
        let handle = try XCTUnwrap(dlopen(library.path, RTLD_NOW | RTLD_LOCAL), loaderError())

        var didClose = false
        defer {
            if !didClose { dlclose(handle) }
            // The native caches can still reference borrowed fixture pointers. Ensure we isolate following tests.
            ksdl_resetCache()
            ksdl_init()
        }

        let symbol = try XCTUnwrap(dlsym(handle, "sentry_unloadable_image"), loaderError())

        var info = Dl_info()
        XCTAssertNotEqual(dladdr(symbol, &info), 0)
        let header = UInt64(UInt(bitPattern: try XCTUnwrap(info.dli_fbase)))
        let imagePath = String(cString: try XCTUnwrap(info.dli_fname))
        let registry = UnloadingRegistry(target: header, handle: handle)

        let provider = SentryKSCrash.BinaryImageProvider()
        provider.start(registry: registry)
        defer { provider.stop() }

        // -- Act --
        provider.refresh()
        didClose = registry.closeResult != nil

        // -- Assert --
        XCTAssertEqual(registry.closeResult, 0, loaderError())
        XCTAssertEqual(registry.wasUnmapped, true, "The fixture must be unmapped before extraction")

        // Skipping the unloaded image is fine. However, publishing it is only okay with owned metadata.
        if let image = registry.addedImages.first(where: { $0.address == header }) {
            XCTAssertEqual(image.name, imagePath)
            XCTAssertNotNil(image.uuid)
        }
    }

    private final class UnloadingRegistry: SentryBinaryImageRegistry {
        private let target: UInt64
        private var handle: UnsafeMutableRawPointer?
        private(set) var closeResult: Int32?
        private(set) var wasUnmapped: Bool?
        private(set) var addedImages: [SentryBinaryImageInfo] = []

        init(target: UInt64, handle: UnsafeMutableRawPointer) {
            self.target = target
            self.handle = handle
        }

        func containsBinaryImage(at address: UInt64) -> Bool {
            if address == target, let handle {
                self.handle = nil
                closeResult = dlclose(handle)
                wasUnmapped = !isReadable(address)
            }

            return false
        }

        func binaryImageAdded(_ image: SentryBinaryImageInfo) {
            addedImages.append(image)
        }

        func binaryImageRemoved(at address: UInt64) {}
    }

    private static func isReadable(_ address: UInt64) -> Bool {
        var word: UInt32 = 0
        var copied: vm_size_t = 0
        let result = withUnsafeMutablePointer(to: &word) {
            vm_read_overwrite(
                mach_task_self_, vm_address_t(address), vm_size_t(MemoryLayout<UInt32>.size),
                vm_address_t(UInt(bitPattern: $0)), &copied
            )
        }
        
        return result == KERN_SUCCESS && copied == vm_size_t(MemoryLayout<UInt32>.size)
    }

    private func loaderError() -> String {
        dlerror().map { String(cString: $0) } ?? "No dyld error"
    }
#endif // !SWIFT_PACKAGE || SENTRY_PACKAGE_TEST_FIXTURES

#if os(iOS) && !targetEnvironment(macCatalyst)
    func testImageByAddress_shouldRefreshAfterDynamicImageLoad() throws {
        // -- Arrange --
        sut.start(false)
        let initialImages = sut.getAllBinaryImages()
        let candidates = [
            (path: "/System/Library/Frameworks/EventKit.framework/EventKit", marker: "EventKit.framework/EventKit"),
            (path: "/System/Library/Frameworks/MapKit.framework/MapKit", marker: "MapKit.framework/MapKit"),
            (path: "/System/Library/Frameworks/PDFKit.framework/PDFKit", marker: "PDFKit.framework/PDFKit"),
            (path: "/System/Library/Frameworks/GameplayKit.framework/GameplayKit", marker: "GameplayKit.framework/GameplayKit"),
            (path: "/usr/lib/libbz2.dylib", marker: "libbz2")
        ]

        for candidate in candidates where !initialImages.contains(where: { $0.name.contains(candidate.marker) }) {
            guard let handle = dlopen(candidate.path, RTLD_NOW | RTLD_LOCAL) else { continue }
            guard let header = imageHeader(containing: candidate.marker) else {
                dlclose(handle)
                continue
            }

            // -- Act --
            let image = sut.imageByAddress(UInt64(UInt(bitPattern: header)))
            dlclose(handle)

            // -- Assert --
            let loadedImage = try XCTUnwrap(image)
            XCTAssertTrue(loadedImage.name.contains(candidate.marker))
            return
        }

        XCTFail("Expected an unloaded dynamic-image fixture to be available")
    }

    private func imageHeader(containing marker: String) -> UnsafePointer<mach_header>? {
        for index in 0..<_dyld_image_count() {
            guard let name = _dyld_get_image_name(index) else { continue }
            if String(cString: name).contains(marker) {
                return _dyld_get_image_header(index)
            }
        }
        return nil
    }
#endif // os(iOS) && !targetEnvironment(macCatalyst)
}
#endif // SDK_V10
