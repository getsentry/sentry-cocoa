@testable import Sentry
import XCTest

/** Some of the test parameters are copied during debbuging a working implementation.
 */
class SentryCrashStackEntryMapperTests: XCTestCase {

    func testSymbolAddress() {
        var cursor = SentryCrashStackCursor()
        cursor.stackEntry.symbolAddress = 4_391_813_104
        
        let frame = SentryCrashStackEntryMapper.mapStackEntry(with: cursor)
        
        XCTAssertEqual("0x0000000105c5bff0", frame.symbolAddress ?? "")
    }
    
    func testInstructionAddress() {
        var cursor = SentryCrashStackCursor()
        cursor.stackEntry.address = 4_412_813_376
        
        let frame = SentryCrashStackEntryMapper.mapStackEntry(with: cursor)
        
        XCTAssertEqual("0x0000000107063040", frame.instructionAddress ?? "")
    }
    
    func testSymbolNameIsNull() {
        let frame = SentryCrashStackEntryMapper.mapStackEntry(with: SentryCrashStackCursor())
        
        XCTAssertEqual("<redacted>", frame.function)
    }
    
    func testSymbolName() {
        let symbolName = "-[SentryCrash symbolName]"
        var cursor = SentryCrashStackCursor()
        var buffer: [Int8] = Array(repeating: 0, count: 256)
        strcpy(&buffer, symbolName)
        cursor.stackEntry.symbolName = UnsafePointer(buffer)
        
        let frame = SentryCrashStackEntryMapper.mapStackEntry(with: cursor)
        XCTAssertEqual(symbolName, frame.function)
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
    
    func testImageAddress () {
        var cursor = SentryCrashStackCursor()
        cursor.stackEntry.imageAddress = 4_488_998_912
        
        let frame = SentryCrashStackEntryMapper.mapStackEntry(with: cursor)
        
        XCTAssertEqual("0x000000010b90b000", frame.imageAddress ?? "")
    }
    
    private func getFrameWithImageName(imageName: String) -> Frame {
        var cursor = SentryCrashStackCursor()
        var buffer: [Int8] = Array(repeating: 0, count: 256)
        strcpy(&buffer, imageName)
        cursor.stackEntry.imageName = UnsafePointer(buffer)
        
        return SentryCrashStackEntryMapper.mapStackEntry(with: cursor)
    }
}
