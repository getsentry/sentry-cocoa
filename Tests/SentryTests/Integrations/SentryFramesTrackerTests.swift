import XCTest

@available(iOS 10.0, *)
class SentryFramesTrackerTests: XCTestCase {
    
    private class Fixture {
        
        var displayLinkWrapper: TestDiplayLinkWrapper
        
        init() {
            displayLinkWrapper = TestDiplayLinkWrapper()
        }
        
        var sut: SentryFramesTracker {
            return SentryFramesTracker(options: Options(), displayLinkWrapper: displayLinkWrapper)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        fixture = Fixture()
    }
    
    func testFrames_ConcurrentRead() {
        let sut = fixture.sut
        
        sut.start()
        
        let queue = DispatchQueue(label: "SentryFramesTrackerTests", qos: .background, attributes: [.concurrent])
        let group = DispatchGroup()
        
        assertBigger(group, queue) { return sut.currentFrozenFrames }
        assertBigger(group, queue) { return sut.currentSlowFrames }
        assertBigger(group, queue) { return sut.currentTotalFrames }
        
        let frames: UInt = 600_000
        for _ in 0 ..< frames {
            fixture.displayLinkWrapper.call()
            fixture.displayLinkWrapper.internalTimestamp += 0.02
            
            fixture.displayLinkWrapper.call()
            fixture.displayLinkWrapper.internalTimestamp += 0.701
        }
        
        group.wait()
        XCTAssertEqual(2 * frames, sut.currentTotalFrames)
        XCTAssertEqual(frames, sut.currentSlowFrames)
        XCTAssertEqual(frames, sut.currentFrozenFrames)
    }
    
    private func assertBigger(_ group: DispatchGroup, _ queue: DispatchQueue, count:  @escaping () -> UInt) {
        group.enter()
        queue.async {
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
