@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryBinaryImageCacheTests: XCTestCase {
    private var sut: SentryBinaryImageCache {
        SentryDependencyContainer.sharedInstance().binaryImageCache
    }

    override func setUp() {
        super.setUp()
        sut.start(false)
    }

    override func tearDown() {
        sut.stop()
        super.tearDown()
    }
    
    private func addBinaryImageToSut(_ binaryImage: SentryCrashBinaryImage) {
        sut.binaryImageAdded(imageName: binaryImage.name,
                             vmAddress: binaryImage.vmAddress,
                             address: binaryImage.address,
                             size: binaryImage.size,
                             uuid: binaryImage.uuid)
    }

    func testBinaryImageAdded() {
        let binaryImage0 = createCrashBinaryImage(0, vmAddress: 0)
        let binaryImage1 = createCrashBinaryImage(100, vmAddress: 100)
        let binaryImage2 = createCrashBinaryImage(200, vmAddress: 200)
        let binaryImage3 = createCrashBinaryImage(400, vmAddress: 400)
        addBinaryImageToSut(binaryImage1)

        XCTAssertEqual(sut.cache?.count, 1)
        XCTAssertEqual(sut.cache?.first?.name, "Expected Name at 100")
        XCTAssertEqual(sut.cache?.first?.uuid, "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322")
        XCTAssertEqual(sut.cache?.first?.vmAddress, 100)

        addBinaryImageToSut(binaryImage3)
        XCTAssertEqual(sut.cache?.count, 2)
        XCTAssertEqual(sut.cache?.last?.name, "Expected Name at 400")
        XCTAssertEqual(sut.cache?.last?.uuid, "84BAEBDA-AD1A-33F4-B35D-8A45F5DAF322")
        XCTAssertEqual(sut.cache?.last?.vmAddress, 400)

        addBinaryImageToSut(binaryImage2)
        XCTAssertEqual(sut.cache?.count, 3)
        XCTAssertEqual(sut.cache?.first?.name, "Expected Name at 100")
        XCTAssertEqual(try XCTUnwrap(sut.cache?.element(at: 1)).name, "Expected Name at 200")
        XCTAssertEqual(sut.cache?.last?.name, "Expected Name at 400")

        addBinaryImageToSut(binaryImage0)
        XCTAssertEqual(sut.cache?.count, 4)
        XCTAssertEqual(sut.cache?.first?.name, "Expected Name at 0")
        XCTAssertEqual(try XCTUnwrap(sut.cache?.element(at: 1)).name, "Expected Name at 100")
    }
    
    func testBinaryImageAdded_WithNilName() {
        sut.binaryImageAdded(imageName: nil,
                             vmAddress: 100,
                             address: 1_000,
                             size: 100,
                             uuid: nil)
        
        XCTAssertEqual(self.sut.cache?.count, 0)
    }

    func testBinaryImageRemoved() {
        let binaryImage0 = createCrashBinaryImage(0)
        let binaryImage1 = createCrashBinaryImage(100)
        let binaryImage2 = createCrashBinaryImage(200)
        let binaryImage3 = createCrashBinaryImage(400)

        addBinaryImageToSut(binaryImage1)
        addBinaryImageToSut(binaryImage3)
        addBinaryImageToSut(binaryImage2)
        addBinaryImageToSut(binaryImage0)
        XCTAssertEqual(sut.cache?.count, 4)

        XCTAssertEqual(sut.imageByAddress(150)?.name, "Expected Name at 100")
        sut.binaryImageRemoved(binaryImage1.address)
        XCTAssertEqual(sut.cache?.count, 3)
        XCTAssertNil(sut.imageByAddress(100))

        XCTAssertEqual(sut.imageByAddress(450)?.name, "Expected Name at 400")
        sut.binaryImageRemoved(binaryImage3.address)
        XCTAssertEqual(sut.cache?.count, 2)
        XCTAssertNil(sut.imageByAddress(400))

        XCTAssertEqual(sut.imageByAddress(0)?.name, "Expected Name at 0")
        sut.binaryImageRemoved(binaryImage0.address)
        XCTAssertEqual(sut.cache?.count, 1)
        XCTAssertNil(sut.imageByAddress(0))

        XCTAssertEqual(sut.imageByAddress(200)?.name, "Expected Name at 200")
        sut.binaryImageRemoved(binaryImage2.address)
        XCTAssertEqual(sut.cache?.count, 0)
        XCTAssertNil(sut.imageByAddress(240))
    }
    
    func testBinaryImageRemoved_InvalidAddress() {
        let binaryImage = createCrashBinaryImage(0)
        addBinaryImageToSut(binaryImage)
        
        sut.binaryImageRemoved(1_000_000)
        
        XCTAssertEqual(self.sut.cache?.count, 1)
    }

    func testImageNameByAddress() {
        let binaryImage0 = createCrashBinaryImage(0)
        let binaryImage1 = createCrashBinaryImage(100)
        let binaryImage2 = createCrashBinaryImage(200)
        let binaryImage3 = createCrashBinaryImage(400)

        addBinaryImageToSut(binaryImage1)
        addBinaryImageToSut(binaryImage3)
        addBinaryImageToSut(binaryImage2)
        addBinaryImageToSut(binaryImage0)

        XCTAssertEqual(sut.imageByAddress(150)?.name, "Expected Name at 100")
        XCTAssertEqual(sut.imageByAddress(0)?.name, "Expected Name at 0")
        XCTAssertEqual(sut.imageByAddress(10)?.name, "Expected Name at 0")
        XCTAssertEqual(sut.imageByAddress(99)?.name, "Expected Name at 0")
        XCTAssertEqual(sut.imageByAddress(200)?.name, "Expected Name at 200")
        XCTAssertEqual(sut.imageByAddress(299)?.name, "Expected Name at 200")
        XCTAssertEqual(sut.imageByAddress(400)?.name, "Expected Name at 400")
        XCTAssertNil(sut.imageByAddress(300))
        XCTAssertNil(sut.imageByAddress(399))
    }
    
    func testImagePathByName() {
        let binaryImage = createCrashBinaryImage(0)
        let binaryImage2 = createCrashBinaryImage(1)
        addBinaryImageToSut(binaryImage)
        addBinaryImageToSut(binaryImage2)
        
        let paths = sut.imagePathsFor(inAppInclude: "Expected Name at 0")
        XCTAssertEqual(paths.first, "Expected Name at 0")
        
        let paths2 = sut.imagePathsFor(inAppInclude: "Expected Name at 1")
        XCTAssertEqual(paths2.first, "Expected Name at 1")
        
        let bothPaths = sut.imagePathsFor(inAppInclude: "Expected")
        XCTAssertEqual(bothPaths, ["Expected Name at 0", "Expected Name at 1"])
        
        let didNotFind = sut.imagePathsFor(inAppInclude: "Name at 0")
        XCTAssertTrue(didNotFind.isEmpty)
    }
    
    func testBinaryImageWithNULLName_DoesNotAddImage() {
        let address = UInt64(100)
    
        let binaryImage = SentryCrashBinaryImage(
            address: address,
            vmAddress: 0,
            size: 100,
            name: nil,
            uuid: nil,
            cpuType: 1,
            cpuSubType: 1,
            crashInfoMessage: nil,
            crashInfoMessage2: nil
        )
        
        addBinaryImageToSut(binaryImage)
        XCTAssertNil(self.sut.imageByAddress(address))
        XCTAssertEqual(self.sut.cache?.count, 0)
    }
    
    func testBinaryImageNameDifferentEncoding_DoesNotAddImage() {
        let name = NSString(string: "こんにちは") // "Hello" in Japanese
        // 8 = NSShiftJISStringEncoding
        // Passing NSShiftJISStringEncoding directly doesn't work on older Xcode versions.
        let nameCString = name.cString(using: UInt(8))
        let address = UInt64(100)
    
        let binaryImage = SentryCrashBinaryImage(
            address: address,
            vmAddress: 0,
            size: 100,
            name: nameCString,
            uuid: nil,
            cpuType: 1,
            cpuSubType: 1,
            crashInfoMessage: nil,
            crashInfoMessage2: nil
        )
        
        addBinaryImageToSut(binaryImage)
        XCTAssertNil(self.sut.imageByAddress(address))
        XCTAssertEqual(self.sut.cache?.count, 0)
    }
    
    func testAddingImagesWhileStoppingAndStartingOnDifferentThread() {
        let count = 1_000
        
        let expectation = expectation(description: "Add images on background thread")
        expectation.expectedFulfillmentCount = count
        
        for i in 0..<count {
            DispatchQueue.global().async {
                let binaryImage0 = createCrashBinaryImage(UInt(i * 10))
                self.addBinaryImageToSut(binaryImage0)
                
                self.sut.stop()
                self.sut.start(false)
                
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10)
    }
    
    func testAddingImagesWhileGettingAllOnDifferentThread() {
        let count = 1_000
        
        let expectation = expectation(description: "Add images on background thread")
        expectation.expectedFulfillmentCount = count
        
        self.sut.start(false)
        
        for i in 0..<count {
            DispatchQueue.global().async {
                let binaryImage = createCrashBinaryImage(UInt(i * 10), name: "image")
                self.addBinaryImageToSut(binaryImage)
                
                let allBinaryImages = self.sut.getAllBinaryImages()
                XCTAssertGreaterThan(allBinaryImages.count, 0)
                
                for image in allBinaryImages {
                    XCTAssertEqual("image", image.name)
                }
                
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10)
    }
}

func createCrashBinaryImage(_ address: UInt, vmAddress: UInt64 = 0, name: String? = nil) -> SentryCrashBinaryImage {
   let imageName = name ?? "Expected Name at \(address)"
   let nameCString = imageName.withCString { strdup($0) }
   
   var uuidPointer = UnsafeMutablePointer<UInt8>(nil)
   let uuidAsCharArray: [UInt8] = [132, 186, 235, 218, 173, 26, 51, 244, 179, 93, 138, 69, 245, 218, 243, 34]
   uuidPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: uuidAsCharArray.count)
   uuidPointer?.initialize(from: uuidAsCharArray, count: uuidAsCharArray.count)

   let binaryImage = SentryCrashBinaryImage(
       address: UInt64(address),
       vmAddress: vmAddress,
       size: 100,
       name: nameCString,
       uuid: uuidPointer,
       cpuType: 1,
       cpuSubType: 1,
       crashInfoMessage: nil,
       crashInfoMessage2: nil
   )

   return binaryImage
}
