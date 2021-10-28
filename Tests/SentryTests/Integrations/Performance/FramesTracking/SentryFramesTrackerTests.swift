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
        fixture.displayLinkWrapper.internalTimestamp += TestData.slowFrameThreshold + 0.001
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.internalTimestamp += TestData.slowFrameThreshold
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.internalTimestamp += TestData.frozenFrameThreshold
        fixture.displayLinkWrapper.call()
        
        let currentFrames = sut.currentFrames
        XCTAssertEqual(2, currentFrames.slow)
        XCTAssertEqual(3, currentFrames.total)
        XCTAssertEqual(0, currentFrames.frozen)
    }
    
    func testFrozenFrame() {
        let sut = fixture.sut
        sut.start()
        
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.internalTimestamp += TestData.frozenFrameThreshold + 0.001
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.internalTimestamp += TestData.frozenFrameThreshold
        fixture.displayLinkWrapper.call()
        
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
        assertPreviousCountBiggerThanCurrent(group) { return currentFrames.frozen }
        assertPreviousCountBiggerThanCurrent(group) { return currentFrames.slow }
        assertPreviousCountBiggerThanCurrent(group) { return currentFrames.total }
        
        fixture.displayLinkWrapper.call()
        
        let frames: UInt = 600_000
        for _ in 0 ..< frames {
            fixture.displayLinkWrapper.internalTimestamp += TestData.slowFrameThreshold + 0.001
            fixture.displayLinkWrapper.call()
            
            fixture.displayLinkWrapper.internalTimestamp += TestData.frozenFrameThreshold + 0.001
            fixture.displayLinkWrapper.call()
        }
        
        group.wait()
        currentFrames = sut.currentFrames
        XCTAssertEqual(2 * frames, currentFrames.total)
        XCTAssertEqual(frames, currentFrames.slow)
        XCTAssertEqual(frames, currentFrames.frozen)
    }
    
    func testPerformanceOfTrackingFrames() {
        let sut = fixture.sut
        sut.start()
        
        let frames: UInt = 1_000
        self.measure {
            for _ in 0 ..< frames {
                fixture.displayLinkWrapper.call()
                fixture.displayLinkWrapper.internalTimestamp += TestData.slowFrameThreshold
            }
        }
    }
    
    private func assertPreviousCountBiggerThanCurrent(_ group: DispatchGroup, count:  @escaping () -> UInt) {
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
