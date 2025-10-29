#if os(iOS)

@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
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
    
    private var dateprovider = TestCurrentDateProvider()
    
    override func setUp() {
        super.setUp()
        dateprovider.advance(by: 5)
        dateprovider.setSystemUptime(5)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    private var referenceDate = Date(timeIntervalSinceReferenceDate: 0)
    
    private func getSut(dispatchQueue: SentryDispatchQueueWrapper = TestSentryDispatchQueueWrapper()) -> SentryTouchTracker {
        return SentryTouchTracker(dateProvider: dateprovider, scale: 1, dispatchQueue: dispatchQueue)
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
    
    func testAddingReadingFlushing_DoesNotCrash() {
        // Arrange
        let iterations = 100

        let sut = getSut(dispatchQueue: SentryDispatchQueueWrapper())
        
        let addExp = expectation(description: "add")
        addExp.expectedFulfillmentCount = iterations
        let removeExp = expectation(description: "remove")
        removeExp.expectedFulfillmentCount = iterations
        let readExp = expectation(description: "read")
        readExp.expectedFulfillmentCount = iterations

        let dispatchQueue = DispatchQueue(label: "sentry.test.queue", attributes: [.concurrent, .initiallyInactive])

        // Act
        for i in 0..<iterations {
            dispatchQueue.async {
                let event = MockUIEvent(timestamp: Double(i))
                let touch = MockUITouch(phase: .ended, location: CGPoint(x: 100, y: 100))
                event.addTouch(touch)
                sut.trackTouchFrom(event: event)

                addExp.fulfill()
            }

            dispatchQueue.async {
                sut.flushFinishedEvents()
                removeExp.fulfill()
            }

            dispatchQueue.async {
                _ = sut.replayEvents(from: self.referenceDate, until: self.referenceDate.addingTimeInterval(10_000.0))
                readExp.fulfill()
            }
        }

        dispatchQueue.activate()

        // Assert
        wait(for: [addExp, removeExp, readExp], timeout: 5)
    }
    
    func testObjectIdentifierCollision_NewTouchGetsNewId() {
        // Arrange
        // This test simulates ObjectIdentifier collision when UITouch memory is reused.
        // When iOS reuses memory for a new UITouch at the same address as a previous touch,
        // the ObjectIdentifier will be the same, but it's actually a different touch gesture.
        let sut = getSut()
        let touch = MockUITouch(phase: .began, location: CGPoint(x: 100, y: 100))
        
        // Act - First touch lifecycle (began -> moved -> ended)
        let event1 = MockUIEvent(timestamp: 1)
        event1.addTouch(touch)
        sut.trackTouchFrom(event: event1)
        
        touch.phase = .moved
        touch.location = CGPoint(x: 150, y: 150)
        let event2 = MockUIEvent(timestamp: 2)
        event2.addTouch(touch)
        sut.trackTouchFrom(event: event2)
        
        touch.phase = .ended
        touch.location = CGPoint(x: 200, y: 200)
        let event3 = MockUIEvent(timestamp: 3)
        event3.addTouch(touch)
        sut.trackTouchFrom(event: event3)
        
        // Get events from first touch before they're overwritten
        let firstTouchEvents = sut.replayEvents(from: referenceDate, until: referenceDate.addingTimeInterval(10))
        
        // In real-world usage, flushFinishedEvents would be called periodically
        // This removes finished touches from trackedTouches
        sut.flushFinishedEvents()
        
        // Simulate memory reuse: same UITouch object starts a NEW touch gesture
        // In reality this would be a new UITouch at the same memory address,
        // but for testing we can use the same object with .began phase at a different location
        touch.phase = .began
        touch.location = CGPoint(x: 50, y: 50)  // Different location - this is a NEW touch
        let event4 = MockUIEvent(timestamp: 4)
        event4.addTouch(touch)
        sut.trackTouchFrom(event: event4)
        
        touch.phase = .ended
        touch.location = CGPoint(x: 75, y: 75)
        let event5 = MockUIEvent(timestamp: 5)
        event5.addTouch(touch)
        sut.trackTouchFrom(event: event5)
        
        // Get second touch events
        let secondTouchEvents = sut.replayEvents(from: referenceDate, until: referenceDate.addingTimeInterval(10))
        
        // Assert - First touch (captured before flush)
        XCTAssertEqual(firstTouchEvents.count, 3, "First touch should have 3 events: start, move, end")
        
        let firstTouchStart = firstTouchEvents[0].data
        let firstTouchPointerId = firstTouchStart?["pointerId"] as? Int
        XCTAssertEqual(firstTouchStart?["x"] as? Float, 100)
        XCTAssertEqual(firstTouchStart?["y"] as? Float, 100)
        XCTAssertEqual(firstTouchStart?["type"] as? Int, TouchEventPhase.start.rawValue)
        XCTAssertEqual(firstTouchPointerId, 1, "First touch should have pointer ID 1")
        
        let firstTouchMove = firstTouchEvents[1].data
        XCTAssertEqual(firstTouchMove?["pointerId"] as? Int, firstTouchPointerId)
        
        let firstTouchEnd = firstTouchEvents[2].data
        XCTAssertEqual(firstTouchEnd?["x"] as? Float, 200)
        XCTAssertEqual(firstTouchEnd?["y"] as? Float, 200)
        XCTAssertEqual(firstTouchEnd?["type"] as? Int, TouchEventPhase.end.rawValue)
        XCTAssertEqual(firstTouchEnd?["pointerId"] as? Int, firstTouchPointerId)
        
        // Assert - Second touch (after collision)
        XCTAssertEqual(secondTouchEvents.count, 2, "Second touch should have 2 events: start, end")
        
        let secondTouchStart = secondTouchEvents[0].data
        let secondTouchPointerId = secondTouchStart?["pointerId"] as? Int
        XCTAssertEqual(secondTouchStart?["x"] as? Float, 50)
        XCTAssertEqual(secondTouchStart?["y"] as? Float, 50)
        XCTAssertEqual(secondTouchStart?["type"] as? Int, TouchEventPhase.start.rawValue)
        XCTAssertEqual(secondTouchPointerId, 2, "Second touch should have pointer ID 2")
        
        let secondTouchEnd = secondTouchEvents[1].data
        XCTAssertEqual(secondTouchEnd?["x"] as? Float, 75)
        XCTAssertEqual(secondTouchEnd?["y"] as? Float, 75)
        XCTAssertEqual(secondTouchEnd?["type"] as? Int, TouchEventPhase.end.rawValue)
        XCTAssertEqual(secondTouchEnd?["pointerId"] as? Int, secondTouchPointerId)
        
        // Critical assertion: The two touches should have DIFFERENT pointer IDs
        XCTAssertNotEqual(firstTouchPointerId, secondTouchPointerId,
                         "Memory-reused touch should get a new pointer ID, not inherit the old one")
    }
}
#endif
