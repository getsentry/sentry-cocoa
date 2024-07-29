#if os(iOS)

@testable import Sentry
import SentryTestUtils
import XCTest

class SentryTouchTrackerTests: XCTestCase {
        
    private class MockUIEvent: UIEvent {
        var mockTouches = Set<UITouch>()
        private var _timestamp: TimeInterval = 0
        
        override var timestamp: TimeInterval {
            get {
                _timestamp
            }
            set {
                _timestamp = newValue
            }
        }
        
        override var allTouches: Set<UITouch>? {
            return mockTouches
        }
        
        func addTouch(_ touch: UITouch) {
            mockTouches.insert(touch)
        }
        
        init(timestamp: TimeInterval = 0) {
            _timestamp = timestamp
        }
    }

    private class MockUITouch: UITouch {
        private var _phase: UITouch.Phase
        var location: CGPoint
        
        init(phase: UITouch.Phase, location: CGPoint) {
            _phase = phase
            self.location = location
            super.init()
        }
        
        override var phase: UITouch.Phase {
            get { _phase }
            set { _phase = newValue }
        }
        
        override func location(in view: UIView?) -> CGPoint {
            return location
        }
    }
    
    var dateprovider = TestCurrentDateProvider()
    
    override func setUp() {
        super.setUp()
        dateprovider.advance(by: 5)
        dateprovider.setSystemUptime(5)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    private var referenceDate = Date(timeIntervalSinceReferenceDate: 0)
    
    func getSut() -> SentryTouchTracker {
        return SentryTouchTracker(dateProvider: dateprovider, scale: 1)
    }
    
    func testTrackTouchFromEvent() {
        let sut = getSut()
        let event = MockUIEvent(timestamp: 3)
        let touch = MockUITouch(phase: .began, location: CGPoint(x: 100, y: 100))
        event.addTouch(touch)
        
        sut.trackTouchFrom(event: event)
        touch.phase = .ended
        event.timestamp = 4
        
        sut.trackTouchFrom(event: event)
        
        let result = sut.replayEvents(from: referenceDate, until: referenceDate.addingTimeInterval(5))
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.timestamp, referenceDate.addingTimeInterval(3))
        XCTAssertEqual(result.first?.type, .touch)
    }
    
    func testTrackTouchBegan() {
        let sut = getSut()
        let event = MockUIEvent(timestamp: 3)
        event.addTouch(MockUITouch(phase: .began, location: CGPoint(x: 100, y: 100)))
        sut.trackTouchFrom(event: event)
        
        let result = sut.replayEvents(from: referenceDate, until: referenceDate.addingTimeInterval(5))
        let data = result.first?.data
        
        XCTAssertEqual(data?["x"] as? Float, 100)
        XCTAssertEqual(data?["y"] as? Float, 100)
        XCTAssertEqual(data?["type"] as? Int, TouchEventPhase.start.rawValue)
        XCTAssertEqual(data?["pointerId"] as? Int, 1)
        XCTAssertEqual(data?["pointerType"] as? Int, 2)
        XCTAssertEqual(data?["source"] as? Int, 2)
    }
    
    func testTrackTouchEnded() {
        let sut = getSut()
        let event = MockUIEvent(timestamp: 3)
        event.addTouch(MockUITouch(phase: .ended, location: CGPoint(x: 100, y: 100)))
        sut.trackTouchFrom(event: event)
        
        let result = sut.replayEvents(from: referenceDate, until: referenceDate.addingTimeInterval(5))
        let data = result.first?.data
        
        XCTAssertEqual(data?["x"] as? Float, 100)
        XCTAssertEqual(data?["y"] as? Float, 100)
        XCTAssertEqual(data?["type"] as? Int, TouchEventPhase.end.rawValue)
        XCTAssertEqual(data?["pointerId"] as? Int, 1)
        XCTAssertEqual(data?["pointerType"] as? Int, 2)
        XCTAssertEqual(data?["source"] as? Int, 2)
    }
    
    func testTrackTouchCanceled() {
        let sut = getSut()
        let event = MockUIEvent(timestamp: 3)
        event.addTouch(MockUITouch(phase: .cancelled, location: CGPoint(x: 100, y: 100)))
        sut.trackTouchFrom(event: event)
        
        let result = sut.replayEvents(from: referenceDate, until: referenceDate.addingTimeInterval(5))
        let data = result.first?.data
        
        XCTAssertEqual(data?["x"] as? Float, 100)
        XCTAssertEqual(data?["y"] as? Float, 100)
        XCTAssertEqual(data?["type"] as? Int, TouchEventPhase.end.rawValue)
        XCTAssertEqual(data?["pointerId"] as? Int, 1)
        XCTAssertEqual(data?["pointerType"] as? Int, 2)
        XCTAssertEqual(data?["source"] as? Int, 2)
    }
    
    func testTrackTouchEventKeepSameIdAccrossEvents() throws {
        let sut = getSut()
        let event = MockUIEvent(timestamp: 3)
        let touch = MockUITouch(phase: .began, location: CGPoint(x: 100, y: 100))
        let secondTouch = MockUITouch(phase: .began, location: CGPoint(x: 50, y: 50))
        event.addTouch(touch)
        event.addTouch(secondTouch)
        sut.trackTouchFrom(event: event)
        touch.phase = .ended
        secondTouch.phase = .ended
        event.timestamp = 4
        sut.trackTouchFrom(event: event)
        
        let result = sut.replayEvents(from: referenceDate, until: referenceDate.addingTimeInterval(5))
        let firstEventFirstTouch = try XCTUnwrap(result.first).data
        let firstEventSecondTouch = try XCTUnwrap(result.element(at: 1)).data
        let secondEventFirstTouch = try XCTUnwrap(result.element(at: 2)).data
        let secondEventSecondTouch = try XCTUnwrap(result.element(at: 3)).data
        
        XCTAssertEqual(firstEventFirstTouch?["pointerId"] as? Int, secondEventFirstTouch?["pointerId"] as? Int)
        XCTAssertEqual(firstEventSecondTouch?["pointerId"] as? Int, secondEventSecondTouch?["pointerId"] as? Int)
        XCTAssertNotEqual(firstEventFirstTouch?["pointerId"] as? Int, firstEventSecondTouch?["pointerId"] as? Int)
    }
    
    func testTrackTouchMoved() {
        let sut = getSut()
        let event = MockUIEvent(timestamp: 2)
        let touch = MockUITouch(phase: .moved, location: CGPoint(x: 10, y: 10))
        event.addTouch(touch)
        sut.trackTouchFrom(event: event)
        
        event.timestamp = 3
        touch.location = CGPoint(x: 50, y: 50)
        sut.trackTouchFrom(event: event)
        
        let result = sut.replayEvents(from: referenceDate, until: referenceDate.addingTimeInterval(5))
        let data = result.first?.data
        let positions = data?["positions"] as? [[String: Any]]
        let firstPosition = positions?.first
        let secondPosition = positions?.last
        
        XCTAssertEqual(data?["pointerId"] as? Int, 1)
        XCTAssertEqual(data?["source"] as? Int, 6)
        XCTAssertEqual(positions?.count, 2)
        
        XCTAssertEqual(firstPosition?["x"] as? Float, 10)
        XCTAssertEqual(firstPosition?["y"] as? Float, 10)
        XCTAssertEqual(firstPosition?["timeOffset"] as? Int, -1_000)
        
        XCTAssertEqual(secondPosition?["x"] as? Float, 50)
        XCTAssertEqual(secondPosition?["y"] as? Float, 50)
        XCTAssertEqual(secondPosition?["timeOffset"] as? Int, 0)
    }
    
    func testTrackTouchMoveIgnoreSmallMovement() {
        let sut = getSut()
        let event = MockUIEvent(timestamp: 2)
        let touch = MockUITouch(phase: .moved, location: CGPoint(x: 10, y: 10))
        event.addTouch(touch)
        sut.trackTouchFrom(event: event)
        
        event.timestamp = 3
        touch.location = CGPoint(x: 10, y: 9)
        sut.trackTouchFrom(event: event)
        
        let result = sut.replayEvents(from: referenceDate, until: referenceDate.addingTimeInterval(5))
        let data = result.first?.data
        let positions = data?["positions"] as? [[String: Any]]
        
        XCTAssertEqual(positions?.count, 1)
    }
    
    func testTrackTouchMoveDebounceStraightLines() {
        let sut = getSut()
        let event = MockUIEvent(timestamp: 2)
        let touch = MockUITouch(phase: .moved, location: CGPoint(x: 10, y: 10))
        event.addTouch(touch)
        sut.trackTouchFrom(event: event)
        
        event.timestamp = 2.1
        touch.location = CGPoint(x: 10, y: 50)
        sut.trackTouchFrom(event: event)
        
        event.timestamp = 2.2
        touch.location = CGPoint(x: 10, y: 90)
        sut.trackTouchFrom(event: event)
        
        let result = sut.replayEvents(from: referenceDate, until: referenceDate.addingTimeInterval(5))
        let data = result.first?.data
        let positions = data?["positions"] as? [[String: Any]]
        
        XCTAssertEqual(positions?.count, 2)
    }
    
    func testTrackTouchMoveDontDebounceStraightLinesChangeOfDirection() {
        let sut = getSut()
        let event = MockUIEvent(timestamp: 2)
        let touch = MockUITouch(phase: .moved, location: CGPoint(x: 10, y: 10))
        event.addTouch(touch)
        sut.trackTouchFrom(event: event)
        
        event.timestamp = 2.1
        touch.location = CGPoint(x: 10, y: 50)
        sut.trackTouchFrom(event: event)
        
        event.timestamp = 2.2
        touch.location = CGPoint(x: 10, y: 30)
        sut.trackTouchFrom(event: event)
        
        let result = sut.replayEvents(from: referenceDate, until: referenceDate.addingTimeInterval(5))
        let data = result.first?.data
        let positions = data?["positions"] as? [[String: Any]]
        
        XCTAssertEqual(positions?.count, 3)
    }
    
    func testTrackTouchMoveDontDebounceCurve() {
        let sut = getSut()
        let event = MockUIEvent(timestamp: 2)
        let touch = MockUITouch(phase: .moved, location: CGPoint(x: 10, y: 10))
        event.addTouch(touch)
        sut.trackTouchFrom(event: event)
        
        event.timestamp = 2.1
        touch.location = CGPoint(x: 10, y: 50)
        sut.trackTouchFrom(event: event)
        
        event.timestamp = 2.2
        touch.location = CGPoint(x: 50, y: 50)
        sut.trackTouchFrom(event: event)
        
        let result = sut.replayEvents(from: referenceDate, until: referenceDate.addingTimeInterval(5))
        let data = result.first?.data
        let positions = data?["positions"] as? [[String: Any]]
        
        XCTAssertEqual(positions?.count, 3)
    }
    
    func testTrackTouchMoveDontDebouncePauses() {
        let sut = getSut()
        let event = MockUIEvent(timestamp: 2)
        let touch = MockUITouch(phase: .moved, location: CGPoint(x: 10, y: 10))
        event.addTouch(touch)
        sut.trackTouchFrom(event: event)
        
        event.timestamp = 2.6
        touch.location = CGPoint(x: 10, y: 50)
        sut.trackTouchFrom(event: event)
        
        event.timestamp = 3.2
        touch.location = CGPoint(x: 10, y: 90)
        sut.trackTouchFrom(event: event)
        
        let result = sut.replayEvents(from: referenceDate, until: referenceDate.addingTimeInterval(5))
        let data = result.first?.data
        let positions = data?["positions"] as? [[String: Any]]
        
        XCTAssertEqual(positions?.count, 3)
    }
    
}
#endif
