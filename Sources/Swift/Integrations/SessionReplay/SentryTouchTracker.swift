import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
import UIKit

@objcMembers
class SentryTouchTracker: NSObject {
    
    private struct TouchEvent {
        let x: CGFloat
        let y: CGFloat
        let timestamp: TimeInterval
        let phase: TouchEventPhase
        
        var point: CGPoint {
            CGPoint(x: x, y: y)
        }
    }
    
    private class TouchInfo {
        let id: Int
        
        var start: TouchEvent?
        var end: TouchEvent?
        var movements = [TouchEvent]()
        
        init(id: Int) {
            self.id = id
        }
    }
    
    private var trackedTouches = [UITouch: TouchInfo]()
    private var touchId = 1
    private let dateProvider: SentryCurrentDateProvider
    private let scale: CGAffineTransform
    
    init(dateProvider: SentryCurrentDateProvider, scale: Float) {
        self.dateProvider = dateProvider
        self.scale = CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale))
    }
    
    func trackTouchFrom(event: UIEvent) {
        guard let touches = event.allTouches else { return }
        for touch in touches {
            
            guard touch.phase == .began || touch.phase == .ended || touch.phase == .moved else { continue }
            let info = trackedTouches[touch] ?? TouchInfo(id: touchId++)
            let position = touch.location(in: nil).applying(scale)
            let newEvent = TouchEvent(x: position.x, y: position.y, timestamp: event.timestamp, phase: touch.phase.toRRWebTouchPhase())
            
            switch touch.phase {
            case .began:
                info.start = newEvent
            case .ended, .cancelled:
                info.end = newEvent
            case .moved:
                if let last = info.movements.last, touchesDelta(last.point, position) < 10 { continue }
                info.movements.append(newEvent)
            default:
                continue
            }
            
            print("### Event = \(touch.phase) \(info.id) \(Date())")
            
            trackedTouches[touch] = info
            debounceEvents(in: info)
        }
    }
    
    private func touchesDelta(_ lastTouch: CGPoint, _ newTouch: CGPoint) -> CGFloat {
        let dx = newTouch.x - lastTouch.x
        let dy = newTouch.y - lastTouch.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func debounceEvents(in touchInfo: TouchInfo) {
        guard touchInfo.movements.count >= 3 else { return }
        let subset = touchInfo.movements.suffix(3)
        if arePointsCollinear(subset[subset.startIndex].point, subset[subset.startIndex + 1].point, subset[subset.startIndex + 2].point) {
            touchInfo.movements.remove(at: touchInfo.movements.count - 2)
        }
    }
    
    private func arePointsCollinear(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, tolerance: CGFloat = 10) -> Bool {
        let crossProduct = (b.y - a.y) * (c.x - b.x) - (c.y - b.y) * (b.x - a.x)
        return abs(crossProduct) < tolerance
    }
  
    func flushFinishedEvents() {
        trackedTouches = trackedTouches.filter { $0.value.end == nil }
    }
    
    func replayEvents(from: Date, until: Date) -> [SentryRRWebEvent] {
        let uptime = ProcessInfo.processInfo.systemUptime
        let now = Date()
        let startTimeInterval = uptime - now.timeIntervalSince(from)
        let endTimeInterval = uptime - now.timeIntervalSince(until)
        
        var result = [SentryRRWebEvent]()
        
        for info in trackedTouches.values {
            if let infoStart = info.start, infoStart.timestamp >= startTimeInterval && infoStart.timestamp <= endTimeInterval {
                result.append(RRWebTouchEvent(timestamp: now.addingTimeInterval(infoStart.timestamp - uptime), touchId: info.id, x: Float(infoStart.x), y: Float(infoStart.y), phase: .start))
            }
            
            let movements: [TouchPosition] = info.movements.compactMap { movement in
                movement.timestamp >= startTimeInterval && movement.timestamp <= endTimeInterval
                    ? TouchPosition(x: Float(movement.x), y: Float(movement.y), timestamp: now.addingTimeInterval(movement.timestamp - uptime))
                    : nil
            }
            
            if let lastMovement = movements.last {
                result.append(RRWebMoveEvent(timestamp: lastMovement.timestamp, touchId: info.id, positions: movements))
            }
            
            if let infoEnd = info.end, infoEnd.timestamp >= startTimeInterval && infoEnd.timestamp <= endTimeInterval {
                result.append(RRWebTouchEvent(timestamp: now.addingTimeInterval(infoEnd.timestamp - uptime), touchId: info.id, x: Float(infoEnd.x), y: Float(infoEnd.y), phase: .end))
            }
        }

        return result.sorted { $0.timestamp.compare($1.timestamp) == .orderedAscending }
    }
}

private extension UITouch.Phase {
    func toRRWebTouchPhase() -> TouchEventPhase {
        switch self {
            case .began: .start
            case .ended, .cancelled: .end
            default: .unknown
        }
    }
}

#endif
