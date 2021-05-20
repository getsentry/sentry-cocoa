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
        fixture = Fixture()
    }
    
    func testSlowFrame() {
        let sut = fixture.sut
        sut.start()
        
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.internalTimestamp += TestData.slowFrameThreshold + 0.001
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.internalTimestamp += TestData.slowFrameThreshold
        fixture.displayLinkWrapper.call()
        
        XCTAssertEqual(1, sut.currentSlowFrames)
        XCTAssertEqual(2, sut.currentTotalFrames)
        XCTAssertEqual(0, sut.currentFrozenFrames)
    }
    
    func testFrozenFrame() {
        let sut = fixture.sut
        sut.start()
        
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.internalTimestamp += TestData.frozenFrameThreshold + 0.001
        fixture.displayLinkWrapper.call()
        fixture.displayLinkWrapper.internalTimestamp += TestData.frozenFrameThreshold
        fixture.displayLinkWrapper.call()
        
        XCTAssertEqual(1, sut.currentSlowFrames)
        XCTAssertEqual(2, sut.currentTotalFrames)
        XCTAssertEqual(1, sut.currentFrozenFrames)
    }
    
    func testAllFrames_ConcurrentRead() {
        let sut = fixture.sut
        sut.start()
        
        let group = DispatchGroup()
        
        assertPreviousCountBiggerThanCurrent(group) { return sut.currentFrozenFrames }
        assertPreviousCountBiggerThanCurrent(group) { return sut.currentSlowFrames }
        assertPreviousCountBiggerThanCurrent(group) { return sut.currentTotalFrames }
        
        fixture.displayLinkWrapper.call()
        
        let frames: UInt = 600_000
        for _ in 0 ..< frames {
            fixture.displayLinkWrapper.internalTimestamp += TestData.slowFrameThreshold + 0.001
            fixture.displayLinkWrapper.call()
            
            fixture.displayLinkWrapper.internalTimestamp += TestData.frozenFrameThreshold + 0.001
            fixture.displayLinkWrapper.call()
        }
        
        group.wait()
        XCTAssertEqual(2 * frames, sut.currentTotalFrames)
        XCTAssertEqual(frames, sut.currentSlowFrames)
        XCTAssertEqual(frames, sut.currentFrozenFrames)
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
