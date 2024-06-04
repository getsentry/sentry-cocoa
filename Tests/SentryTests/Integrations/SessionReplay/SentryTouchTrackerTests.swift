@testable import Sentry
import SentryTestUtils
import XCTest

class SentryTouchTrackerTests: XCTestCase {
        
    private class MockUIEvent: UIEvent {
        var mockTouches = Set<UITouch>()
        
        override var allTouches: Set<UITouch>? {
            return mockTouches
        }
        
        func addTouch(_ touch: UITouch) {
            mockTouches.insert(touch)
        }
    }

    private class MockUITouch: UITouch {
        private var _phase: UITouch.Phase
        private var _location: CGPoint
        
        init(phase: UITouch.Phase, location: CGPoint) {
            _phase = phase
            _location = location
            super.init()
        }
        
        override var phase: UITouch.Phase {
            return _phase
        }
        
        override func location(in view: UIView?) -> CGPoint {
            return _location
        }
    }
    
    var dateprovider = TestCurrentDateProvider()
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func getSut() -> SentryTouchTracker {
        return SentryTouchTracker(dateProvider: dateprovider)
    }
    
    func testTrackTouchFromEvent() {
        let event = MockUIEvent()
        let touch = MockUITouch(phase: .began, location: CGPoint(x: 100, y: 100))
        event.addTouch(touch)
        
        touchTracker.trackTouchFrom(event: event)
        touchTracker.replayEvents(from: <#T##Date#>, until: <#T##Date#>)
        
        XCTAssertEqual(touchTracker.trackedTouches.count, 1)
    }
    
    func testTouchesDelta() {
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 3, y: 4)
        
        let delta = touchTracker.touchesDelta(point1, point2)
        
        XCTAssertEqual(delta, 5)
    }
    
    func testDebounceEvents() {
        let touchInfo = SentryTouchTracker.TouchInfo(id: 1)
        touchInfo.events.append(SentryTouchTracker.TouchEvent(x: 0, y: 0, timestamp: 0, phase: .move))
        touchInfo.events.append(SentryTouchTracker.TouchEvent(x: 10, y: 10, timestamp: 1, phase: .move))
        touchInfo.events.append(SentryTouchTracker.TouchEvent(x: 20, y: 20, timestamp: 2, phase: .move))
        
        touchTracker.debounceEvents(in: touchInfo)
        
        XCTAssertEqual(touchInfo.events.count, 2)
    }
    
    func testArePointsCollinear() {
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 10, y: 10)
        let point3 = CGPoint(x: 20, y: 20)
        
        let result = touchTracker.arePointsCollinear(point1, point2, point3)
        
        XCTAssertTrue(result)
    }
    
    func testFlushFinishedEvents() {
        let event = MockUIEvent()
        let touch = MockUITouch(phase: .ended, location: CGPoint(x: 100, y: 100))
        event.addTouch(touch)
        
        touchTracker.trackTouchFrom(event: event)
        touchTracker.flushFinishedEvents()
        
        XCTAssertEqual(touchTracker.trackedTouches.count, 0)
    }
    
    func testReplayEvents() {
        let event = MockUIEvent()
        let touch = MockUITouch(phase: .began, location: CGPoint(x: 100, y: 100))
        event.addTouch(touch)
        
        touchTracker.trackTouchFrom(event: event)
        
        let fromDate = Date().addingTimeInterval(-100)
        let untilDate = Date().addingTimeInterval(100)
        
        let replayedEvents = touchTracker.replayEvents(from: fromDate, until: untilDate)
        
        XCTAssertEqual(replayedEvents.count, 1)
    }
}
