@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

class SentryStacktraceBuilderTests: XCTestCase {
    
    private class Fixture {
        let queue = DispatchQueue(label: "SentryStacktraceBuilderTests")

        var sut: SentryStacktraceBuilder {
            SentryDependencyContainer.sharedInstance().reachability = TestSentryReachability()
            let res = SentryStacktraceBuilder(crashStackEntryMapper: SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: [])))
            return res
        }
    }

    private var fixture: Fixture!
    
    override class func setUp() {
        super.setUp()
        clearTestState()
    }

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testEnoughFrames() {
        let actual = fixture.sut.buildStacktraceForCurrentThread()
        
        // The stacktrace has usually more than 40 frames. Feel free to change the number if the tests are failing
        XCTAssertTrue(30 < actual.frames.count, "Not enough stacktrace frames. It should be more than 30, but was \(actual.frames.count)")
    }
    
    func testFramesAreFilled() {
        let actual = fixture.sut.buildStacktraceForCurrentThread()
        
        // We don't know the actual values of the frames so we can't write
        // deterministic tests here. Therefore we just make sure they are
        // filled with some values.
        for frame in actual.frames {
            XCTAssertNotNil(frame.imageAddress)
            XCTAssertNotNil(frame.instructionAddress)
        }
    }
    
    func testFramesOrder() throws {
        // -- Act --
        let actual = fixture.sut.buildStacktraceForCurrentThread()

        // -- Assert --
        // Make sure the first 4 frames contain an address close to the main function
        let isMainInFirstFrames = actual.frames[...3].contains(where: { frame in
            let inst = Int(frame.instructionAddress?.replacingOccurrences(of: "0x", with: "") ?? "", radix: 16) ?? 0
            // Use the symbol name for the first stack entry in dyld
            #if targetEnvironment(simulator)
            return name(for: inst) == "start_sim"
            #else
            return name(for: inst) == "start"
            #endif
        })
        XCTAssertTrue(
            isMainInFirstFrames,
            "Expected frames to be ordered from caller to callee (xctest's main expected in first few frames)."
        )
    }

    @available(macOS 10.15, *)
    func testConcurrentStacktraces() throws {
        SentrySDK.start { options in
            options.dsn = TestConstants.dsnAsString(username: "SentryStacktraceBuilderTests")
            options.swiftAsyncStacktraces = true
            options.debug = true
            options.removeAllIntegrations()
            options.swiftAsyncStacktraces = true
            options.enableCrashHandler = true
        }

        let waitForAsyncToRun = expectation(description: "Wait async functions")
        Task {
            print("\(Date()) [Sentry] [TEST] running async task...")
            let filteredFrames = await self.firstFrame()
            waitForAsyncToRun.fulfill()
            XCTAssertGreaterThanOrEqual(filteredFrames, 3, "The Stacktrace must include the async callers.")
        }

        wait(for: [waitForAsyncToRun], timeout: 10)
    }

    @available(macOS 10.15, *)
    func testConcurrentStacktraces_noStitching() throws {
        SentrySDK.start { options in
            options.dsn = TestConstants.dsnAsString(username: "SentryStacktraceBuilderTests")
            options.swiftAsyncStacktraces = false
            options.debug = true
            options.removeAllIntegrations()
            options.swiftAsyncStacktraces = true
            options.enableCrashHandler = true
        }

        let waitForAsyncToRun = expectation(description: "Wait async functions")
        Task {
            print("\(Date()) [Sentry] [TEST] running async task...")
            let filteredFrames = await self.firstFrame()
            waitForAsyncToRun.fulfill()
            XCTAssertGreaterThanOrEqual(filteredFrames, 1, "The Stacktrace must have only one function.")
        }

        wait(for: [waitForAsyncToRun], timeout: 10)
    }

    @available(macOS 10.15, *)
    private func firstFrame() async -> Int {
        print("\(Date()) [Sentry] [TEST] first async frame about to await...")
        return await innerFrame1()
    }

    @available(macOS 10.15, *)
    private func innerFrame1() async -> Int {
        print("\(Date()) [Sentry] [TEST] second async frame about to await on task...")
        await Task { @MainActor in
            print("\(Date()) [Sentry] [TEST] executing task inside second async frame...")
        }.value
        return await innerFrame2()
    }

    private func innerFrame2() async -> Int {
        let needed = ["firstFrame", "innerFrame1", "innerFrame2"]
        let actual = fixture.sut.buildStacktraceForCurrentThreadAsyncUnsafe()!
        let symbolNames = actual.frames
            .compactMap({ $0.instructionAddress?.replacingOccurrences(of: "0x", with: "") })
            .compactMap { Int($0, radix: 16) }
            .compactMap { addr in
                name(for: addr)
            }
        let filteredFrames = symbolNames
            .filter { needed.contains(where: $0.contains) }
        print("\(Date()) [Sentry] [TEST] returning filtered frames.")
        return filteredFrames.count
    }
    
    private func name(for addr: Int) -> String? {
        var sym = Dl_info()
        dladdr(UnsafeMutableRawPointer(bitPattern: addr), &sym)
        if let symName = sym.dli_sname {
            return String(cString: symName)
        }
        return nil
    }
}
