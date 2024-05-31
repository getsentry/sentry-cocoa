import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
import UIKit

@objcMembers
class SentryTouchTracker: NSObject {
    
    private struct TouchEvent {
        let x: CGFloat
        let y: CGFloat
        let timestamp: TimeInterval
        let phase: SentryRRWebTouchEvent.TouchEventPhase
        
        var point: CGPoint {
            CGPoint(x: x, y: y)
        }
    }
    
    private class TouchInfo {
        let id: Int
        var events = [TouchEvent]()
        
        init(id: Int) {
            self.id = id
        }
    }
    
    private var trackedTouches = [UITouch: TouchInfo]()
    private var touchId = 1
    
    func trackTouchFrom(event: UIEvent) {
        guard let touches = event.allTouches else { return }
        for touch in touches {
            guard touch.phase == .began || touch.phase == .ended || touch.phase == .moved else { continue }
            let info = trackedTouches[touch] ?? TouchInfo(id: touchId++)
            let position = touch.location(in: nil)
            if let last = info.events.last, touch.phase == .moved && last.phase == .move && touchesDelta(last.point, position) < 10 {
                continue
            }
            info.events.append(TouchEvent(x: position.x, y: position.y, timestamp: event.timestamp, phase: touch.phase.toRRWebTouchPhase()))
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
        guard touchInfo.events.count >= 3 else { return }
        let subset = touchInfo.events.suffix(3)
        if arePointsCollinear(subset[subset.startIndex].point, subset[subset.startIndex + 1].point, subset[subset.startIndex + 2].point) {
            touchInfo.events.remove(at: touchInfo.events.count - 2)
        }
    }
    
    private func arePointsCollinear(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, tolerance: CGFloat = 10) -> Bool {
        let crossProduct = (b.y - a.y) * (c.x - b.x) - (c.y - b.y) * (b.x - a.x)
        return abs(crossProduct) < tolerance
    }
  
    func flushFinishedEvents() {
        trackedTouches = trackedTouches.filter { element in
            !element.value.events.contains { event in
                event.phase == .end
            }
        }
    }
    
    func replayEvents(from: Date, until: Date) -> [SentryRRWebTouchEvent] {
        let uptime = ProcessInfo.processInfo.systemUptime
        let startTime = Date()
        return trackedTouches.values.flatMap { touchHistory in
            touchHistory.events.compactMap({ touch in
                let date = startTime.addingTimeInterval(touch.timestamp - uptime)
                return touch.phase != .unknown && from <= date && until >= date
                ? SentryRRWebTouchEvent(timestamp: date, touchId: touchHistory.id, x: Float(touch.x), y: Float(touch.y), phase: touch.phase)
                : nil
            })
        }
    }
}

private extension UITouch.Phase {
    func toRRWebTouchPhase() -> SentryRRWebTouchEvent.TouchEventPhase {
        switch self {
            case .began: .start
            case .ended, .cancelled: .end
            case .moved: .move
            default: .unknown
        }
    }
}

#endif
