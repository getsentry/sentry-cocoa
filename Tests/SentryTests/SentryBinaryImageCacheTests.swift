import XCTest

class SentryBinaryImageCacheTests: XCTestCase {
    var sut: SentryBinaryImageCache {
        SentryDependencyContainer.sharedInstance().binaryImageCache
    }

    override func setUp() {
        super.setUp()
        sut.start()
    }

    override func tearDown() {
        sut.stop()
        super.tearDown()
    }

    func testBinaryImageAdded() {
        var binaryImage0 = createCrashBinaryImage(0)
        var binaryImage1 = createCrashBinaryImage(100)
        var binaryImage2 = createCrashBinaryImage(200)
        var binaryImage3 = createCrashBinaryImage(400)
        sut.binaryImageAdded(&binaryImage1)

        XCTAssertEqual(sut.cache.count, 1)
        XCTAssertEqual(sut.cache.first?.name, "Expected Name at 100")

        sut.binaryImageAdded(&binaryImage3)
        XCTAssertEqual(sut.cache.count, 2)
        XCTAssertEqual(sut.cache.last?.name, "Expected Name at 400")

        sut.binaryImageAdded(&binaryImage2)
        XCTAssertEqual(sut.cache.count, 3)
        XCTAssertEqual(sut.cache.first?.name, "Expected Name at 100")
        XCTAssertEqual(sut.cache[1].name, "Expected Name at 200")
        XCTAssertEqual(sut.cache.last?.name, "Expected Name at 400")

        sut.binaryImageAdded(&binaryImage0)
        XCTAssertEqual(sut.cache.count, 4)
        XCTAssertEqual(sut.cache.first?.name, "Expected Name at 0")
        XCTAssertEqual(sut.cache[1].name, "Expected Name at 100")
    }

    func testBinaryImageRemoved() {
        var binaryImage0 = createCrashBinaryImage(0)
        var binaryImage1 = createCrashBinaryImage(100)
        var binaryImage2 = createCrashBinaryImage(200)
        var binaryImage3 = createCrashBinaryImage(400)

        sut.binaryImageAdded(&binaryImage1)
        sut.binaryImageAdded(&binaryImage3)
        sut.binaryImageAdded(&binaryImage2)
        sut.binaryImageAdded(&binaryImage0)
        XCTAssertEqual(sut.cache.count, 4)

        XCTAssertEqual(sut.image(byAddress: 150)?.name, "Expected Name at 100")
        sut.binaryImageRemoved(&binaryImage1)
        XCTAssertEqual(sut.cache.count, 3)
        XCTAssertNil(sut.image(byAddress: 100))

        XCTAssertEqual(sut.image(byAddress: 450)?.name, "Expected Name at 400")
        sut.binaryImageRemoved(&binaryImage3)
        XCTAssertEqual(sut.cache.count, 2)
        XCTAssertNil(sut.image(byAddress: 400))

        XCTAssertEqual(sut.image(byAddress: 0)?.name, "Expected Name at 0")
        sut.binaryImageRemoved(&binaryImage0)
        XCTAssertEqual(sut.cache.count, 1)
        XCTAssertNil(sut.image(byAddress: 0))

        XCTAssertEqual(sut.image(byAddress: 200)?.name, "Expected Name at 200")
        sut.binaryImageRemoved(&binaryImage2)
        XCTAssertEqual(sut.cache.count, 0)
        XCTAssertNil(sut.image(byAddress: 240))
    }

    func testImageNameByAddress() {
        var binaryImage0 = createCrashBinaryImage(0)
        var binaryImage1 = createCrashBinaryImage(100)
        var binaryImage2 = createCrashBinaryImage(200)
        var binaryImage3 = createCrashBinaryImage(400)

        sut.binaryImageAdded(&binaryImage1)
        sut.binaryImageAdded(&binaryImage3)
        sut.binaryImageAdded(&binaryImage2)
        sut.binaryImageAdded(&binaryImage0)

        XCTAssertEqual(sut.image(byAddress: 150)?.name, "Expected Name at 100")
        XCTAssertEqual(sut.image(byAddress: 0)?.name, "Expected Name at 0")
        XCTAssertEqual(sut.image(byAddress: 10)?.name, "Expected Name at 0")
        XCTAssertEqual(sut.image(byAddress: 99)?.name, "Expected Name at 0")
        XCTAssertEqual(sut.image(byAddress: 200)?.name, "Expected Name at 200")
        XCTAssertEqual(sut.image(byAddress: 299)?.name, "Expected Name at 200")
        XCTAssertEqual(sut.image(byAddress: 400)?.name, "Expected Name at 400")
        XCTAssertNil(sut.image(byAddress: 300))
        XCTAssertNil(sut.image(byAddress: 399))
    }

    func createCrashBinaryImage(_ address: UInt) -> SentryCrashBinaryImage {
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
            majorVersion: 1,
            minorVersion: 0,
            revisionVersion: 0,
            crashInfoMessage: nil,
            crashInfoMessage2: nil
        )

        return binaryImage
    }

}
