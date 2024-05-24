import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
import UIKit

@objcMembers
class SentryTouchTracker: NSObject {
    
    private struct TouchEvent {
        let x: CGFloat
        let y: CGFloat
        let timestamp: TimeInterval
        let phase: UITouch.Phase
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
    private var lock = NSLock()
    
    func trackTouchFrom(event: UIEvent) {
        guard let touches = event.allTouches else { return }
        lock.synchronized {
            for touch in touches {
                let info = trackedTouches[touch] ?? TouchInfo(id: touchId++)
                let position = touch.location(in: nil)
                info.events.append(TouchEvent(x: position.x, y: position.y, timestamp: event.timestamp, phase: touch.phase))
                trackedTouches[touch] = info
            }
        }
    }
    
    func flushFinishedEvents() {
        lock.synchronized {
            trackedTouches = trackedTouches.filter { element in
                element.value.events.contains { event in
                    event.phase == .cancelled || event.phase == .ended
                }
            }
        }
    }
    
    func replayEvents(from: Date, until: Date) -> [SentryRRWebTouchEvent] {
        let uptime = ProcessInfo.processInfo.systemUptime
        let startTime = Date()
        return trackedTouches.values.flatMap { touch in
            touch.events.compactMap({
                let phase = $0.phase.toRRWebTouchPhase()
                let date = startTime.addingTimeInterval($0.timestamp - uptime)
                return phase != .unknown && from <= date && until >= date
                ? SentryRRWebTouchEvent(timestamp: date, touchId: touch.id, x: Float($0.x), y: Float($0.y), phase: phase)
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
