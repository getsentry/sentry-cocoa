import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryFramesTrackerTests: XCTestCase {
    
    private class Fixture {
        
        var displayLinkWrapper: TestDisplayLinkWrapper
        var queue: DispatchQueue
        
        init() {
            displayLinkWrapper = TestDisplayLinkWrapper()
            queue = DispatchQueue(label: "SentryFramesTrackerTests", qos: .background, attributes: [.concurrent])
        }
        
        lazy var sut: SentryFramesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper)
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    func testIsNotRunning_WhenNotStarted() {
        XCTAssertFalse(fixture.sut.isRunning)
    }
    
    func testIsRunning_WhenStarted() {
        let sut = fixture.sut
        sut.start()
        XCTAssertTrue(sut.isRunning)
    }
    
    func testIsNotRunning_WhenStopped() {
        let sut = fixture.sut
        sut.start()
        sut.stop()
        XCTAssertFalse(sut.isRunning)
    }
    
    func testSlowFrame() {
        let sut = fixture.sut
        sut.start()
        
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.slowFrame()
        fixture.displayLinkWrapper.normalFrame()
        fixture.displayLinkWrapper.almostFrozenFrame()

        assert(slow: 2, frozen: 0, total: 3)
    }
    
    func testFrozenFrame() {
        let sut = fixture.sut
        sut.start()
        
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.slowFrame()
        fixture.displayLinkWrapper.frozenFrame()

        assert(slow: 1, frozen: 1, total: 2)
    }

    func testFrameRateChange() {
        let sut = fixture.sut
        sut.start()

        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.slowFrame()
        fixture.displayLinkWrapper.changeFrameRate(120.0)
        fixture.displayLinkWrapper.frozenFrame()

        assert(slow: 1, frozen: 1, total: 2, frameRates: 2)
    }
    
    func testAllFrames_ConcurrentRead() {
        let sut = fixture.sut
        sut.start()
        
        let group = DispatchGroup()

        let currentFrames = sut.currentFrames
        assertPreviousCountLesserThanCurrent(group) { return currentFrames.frozen }
        assertPreviousCountLesserThanCurrent(group) { return currentFrames.slow }
        assertPreviousCountLesserThanCurrent(group) { return currentFrames.total }
        
        fixture.displayLinkWrapper.call()
        
        let frames: UInt = 600_000
        for _ in 0 ..< frames {
            fixture.displayLinkWrapper.normalFrame()
            fixture.displayLinkWrapper.slowFrame()
            fixture.displayLinkWrapper.frozenFrame()
        }
        
        group.wait()
        assert(slow: frames, frozen: frames, total: 3 * frames)
    }
    
    func testPerformanceOfTrackingFrames() {
        let sut = fixture.sut
        sut.start()
        
        let frames: UInt = 1_000
        self.measure {
            for _ in 0 ..< frames {
                fixture.displayLinkWrapper.normalFrame()
            }
        }

        assert(slow: 0, frozen: 0)
    }
}

private extension SentryFramesTrackerTests {
    func assert(slow: UInt? = nil, frozen: UInt? = nil, total: UInt? = nil, frameRates: UInt? = nil) {
        let currentFrames = fixture.sut.currentFrames
        if let total = total {
            XCTAssertEqual(total, currentFrames.total)
        }
        if let slow = slow {
            XCTAssertEqual(slow, currentFrames.slow)
        }
        if let frozen = frozen {
            XCTAssertEqual(frozen, currentFrames.frozen)
        }

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        assertProfilingData(slow: slow, frozen: frozen, frameRates: frameRates)
#endif
    }

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    func assertProfilingData(slow: UInt? = nil, frozen: UInt? = nil, frameRates: UInt? = nil) {
        func assertStartAndEndOrdering(frame: [String: NSNumber]) {
            guard let start = frame["start_timestamp"] else {
                XCTFail("Expected a start timestamp for the frame.")
                return
            }
            guard let end = frame["end_timestamp"] else {
                XCTFail("Expected an end timestamp for the frame.")
                return
            }
            XCTAssert(start.compare(end) != .orderedDescending)
        }

        let currentFrames = fixture.sut.currentFrames

        if let slow = slow {
            XCTAssertEqual(currentFrames.slowFrameTimestamps.count, Int(slow))
            for frame in currentFrames.slowFrameTimestamps {
                assertStartAndEndOrdering(frame: frame)
            }
        }
        if let frozen = frozen {
            XCTAssertEqual(currentFrames.frozenFrameTimestamps.count, Int(frozen))
            for frame in currentFrames.frozenFrameTimestamps {
                assertStartAndEndOrdering(frame: frame)
            }
        }
        if let frameRates = frameRates {
            XCTAssertEqual(currentFrames.frameRateTimestamps.count, Int(frameRates))
        }
    }
#endif

    func assertPreviousCountLesserThanCurrent(_ group: DispatchGroup, count: @escaping () -> UInt) {
        group.enter()
        fixture.queue.async {
            var previousCount: UInt = 0
            for _ in 0 ..< 60_000 {
                let currentCount = count()
                XCTAssertTrue(previousCount <= currentCount)
                previousCount = currentCount
            }
            group.leave()
        }
    }
}

#endif
