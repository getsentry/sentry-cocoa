import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryFramesTrackerTests: XCTestCase {
    
    private class Fixture {
        
        var displayLinkWrapper: TestDiplayLinkWrapper
        var queue: DispatchQueue
        
        init() {
            displayLinkWrapper = TestDiplayLinkWrapper()
            queue = DispatchQueue(label: "SentryFramesTrackerTests", qos: .background, attributes: [.concurrent])
        }
        
        var sut: SentryFramesTracker {
            return SentryFramesTracker(displayLinkWrapper: displayLinkWrapper)
        }
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
        
        let currentFrames = sut.currentFrames
        XCTAssertEqual(2, currentFrames.slow)
        XCTAssertEqual(3, currentFrames.total)
        XCTAssertEqual(0, currentFrames.frozen)
    }
    
    func testFrozenFrame() {
        let sut = fixture.sut
        sut.start()
        
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.slowFrame()
        fixture.displayLinkWrapper.frozenFrame()
        
        let currentFrames = sut.currentFrames
        XCTAssertEqual(1, currentFrames.slow)
        XCTAssertEqual(2, currentFrames.total)
        XCTAssertEqual(1, currentFrames.frozen)
    }
    
    func testAllFrames_ConcurrentRead() {
        let sut = fixture.sut
        sut.start()
        
        let group = DispatchGroup()
        
        var currentFrames = sut.currentFrames
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
        currentFrames = sut.currentFrames
        XCTAssertEqual(3 * frames, currentFrames.total)
        XCTAssertEqual(frames, currentFrames.slow)
        XCTAssertEqual(frames, currentFrames.frozen)
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
        
        XCTAssertEqual(0, sut.currentFrames.slow)
        XCTAssertEqual(0, sut.currentFrames.frozen)
    }
    
    private func assertPreviousCountLesserThanCurrent(_ group: DispatchGroup, count: @escaping () -> UInt) {
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
