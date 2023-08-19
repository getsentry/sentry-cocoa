@testable import Sentry
import XCTest

/** Some of the test parameters are copied during debbuging a working implementation.
 */
class SentryCrashStackEntryMapperTests: XCTestCase {
    
    private let bundleExecutable: String = "iOS-Swift"
    private var sut: SentryCrashStackEntryMapper!
    
    override func setUp() {
        super.setUp()
        sut = SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: [bundleExecutable], inAppExcludes: []))
    }

    func testSymbolAddress() {
        var cursor = SentryCrashStackCursor()
        cursor.stackEntry.symbolAddress = 2_391_813_104
        
        let frame = sut.mapStackEntry(with: cursor)
        
        XCTAssertEqual("0x000000008e902bf0", frame.symbolAddress ?? "")
    }
    
    func testInstructionAddress() {
        var cursor = SentryCrashStackCursor()
        cursor.stackEntry.address = 2_412_813_376
        
        let frame = sut.mapStackEntry(with: cursor)
        
        XCTAssertEqual("0x000000008fd09c40", frame.instructionAddress ?? "")
    }
    
    func testSymbolNameIsNull() {
        let frame = sut.mapStackEntry(with: SentryCrashStackCursor())
        
        XCTAssertEqual("<redacted>", frame.function)
    }

    func testSymbolName() {
        let symbolName = "-[SentryCrash symbolName]"
        var cursor = SentryCrashStackCursor()
        
        let cString = symbolName.cString(using: String.Encoding.utf8)
        cString?.withUnsafeBufferPointer { bufferPointer in
            cursor.stackEntry.symbolName = bufferPointer.baseAddress
            let frame = sut.mapStackEntry(with: cursor)
            XCTAssertEqual(symbolName, frame.function)
        }
    }
    
    func testImageName() {
        let imageName = "/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 13.4.simruntime/Contents/Resources/RuntimeRoot/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
        let frame = getFrameWithImageName(imageName: imageName)
        
        XCTAssertEqual(imageName, frame.package)
    }
    
    func testImageAddress () {
        var cursor = SentryCrashStackCursor()
        cursor.stackEntry.imageAddress = 2_488_998_912

        let frame = sut.mapStackEntry(with: cursor)
        
        XCTAssertEqual("0x00000000945b1c00", frame.imageAddress ?? "")
    }
    
    func testIsInApp() {
        let frame = getFrameWithImageName(imageName: "/private/var/containers/Bundle/Application/03D20FB6-852C-4DD3-B69C-3231FB41C2B1/iOS-Swift.app/\(self.bundleExecutable)")
        XCTAssertEqual(true, frame.inApp)
    }

    func testImageFromCache() {
        var image = createCrashBinaryImage(2_488_998_912)
        SentryDependencyContainer.sharedInstance().binaryImageCache.start()
        SentryDependencyContainer.sharedInstance().binaryImageCache.binaryImageAdded(&image)

        var cursor = SentryCrashStackCursor()
        cursor.stackEntry.address = 2_488_998_950

        let frame = sut.mapStackEntry(with: cursor)

        XCTAssertEqual("0x00000000945b1c00", frame.imageAddress ?? "")
        XCTAssertEqual("Expected Name at 2488998912", frame.package)

        SentryDependencyContainer.sharedInstance().binaryImageCache.stop()
    }
    
    private func getFrameWithImageName(imageName: String) -> Frame {
        var cursor = SentryCrashStackCursor()
        
        let cString = imageName.cString(using: String.Encoding.utf8)
        var result: Frame = Frame()
        cString?.withUnsafeBufferPointer { bufferPointer in
            cursor.stackEntry.imageName = bufferPointer.baseAddress
            result = sut.mapStackEntry(with: cursor)
        }
        
        return result
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
