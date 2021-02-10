@testable import Sentry
import XCTest

/** Some of the test parameters are copied during debbuging a working implementation.
 */
class SentryCrashStackEntryMapperTests: XCTestCase {

    func testSymbolAddress() {
        var cursor = SentryCrashStackCursor()
        cursor.stackEntry.symbolAddress = 2_391_813_104
        
        let frame = SentryCrashStackEntryMapper.mapStackEntry(with: cursor)
        
        XCTAssertEqual("0x000000008e902bf0", frame.symbolAddress ?? "")
    }
    
    func testInstructionAddress() {
        var cursor = SentryCrashStackCursor()
        cursor.stackEntry.address = 2_412_813_376
        
        let frame = SentryCrashStackEntryMapper.mapStackEntry(with: cursor)
        
        XCTAssertEqual("0x000000008fd09c40", frame.instructionAddress ?? "")
    }
    
    func testSymbolNameIsNull() {
        let frame = SentryCrashStackEntryMapper.mapStackEntry(with: SentryCrashStackCursor())
        
        XCTAssertEqual("<redacted>", frame.function)
    }
    
    func testSymbolName() {
        let symbolName = "-[SentryCrash symbolName]"
        var cursor = SentryCrashStackCursor()
        
        let cString = symbolName.cString(using: String.Encoding.utf8)
        cString?.withUnsafeBufferPointer { bufferPointer in
            cursor.stackEntry.symbolName = bufferPointer.baseAddress
            let frame = SentryCrashStackEntryMapper.mapStackEntry(with: cursor)
            XCTAssertEqual(symbolName, frame.function)
        }
    }
    
    func testImageName() {
        let imageName = "/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 13.4.simruntime/Contents/Resources/RuntimeRoot/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
        let frame = getFrameWithImageName(imageName: imageName)
        
        XCTAssertEqual(imageName, frame.package)
    }
    
    func testIsNotInApp() {
        let frame = getFrameWithImageName(imageName: "a")
        XCTAssertEqual(false, frame.inApp)
    }
    
    func testIsInApp() {
        let frame1 = getFrameWithImageName(imageName: "a/Bundle/Application/a")
        XCTAssertEqual(true, frame1.inApp)
        
        let frame2 = getFrameWithImageName(imageName: "a.app/")
        XCTAssertEqual(true, frame2.inApp)
    }
    
    func testXcodeLibraries() {
        let frame1 = getFrameWithImageName(imageName: "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore")
        XCTAssertEqual(false, frame1.inApp)
        
        // If someone has multiple Xcode installations
        let frame2 = getFrameWithImageName(imageName: "/Applications/Xcode 11.app/Contents/")
        XCTAssertEqual(false, frame2.inApp)
        
        // We don't care if someone installed Xcode in a different location that Applications
        let frame3 = getFrameWithImageName(imageName: "/Users/sentry/Downloads/Xcode.app/Contents/")
        XCTAssertEqual(true, frame3.inApp)
    }
    
    func testImageAddress () {
        var cursor = SentryCrashStackCursor()
        cursor.stackEntry.imageAddress = 2_488_998_912
        
        let frame = SentryCrashStackEntryMapper.mapStackEntry(with: cursor)
        
        XCTAssertEqual("0x00000000945b1c00", frame.imageAddress ?? "")
    }
    
    private func getFrameWithImageName(imageName: String) -> Frame {
        var cursor = SentryCrashStackCursor()
        
        let cString = imageName.cString(using: String.Encoding.utf8)
        var result: Frame = Frame()
        cString?.withUnsafeBufferPointer { bufferPointer in
            cursor.stackEntry.imageName = bufferPointer.baseAddress
            result = SentryCrashStackEntryMapper.mapStackEntry(with: cursor)
        }
        
        return result
    }
}
