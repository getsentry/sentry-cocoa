import Foundation

@objcMembers
class SentryRRWebTouchEvent: SentryRRWebEvent {
    
    enum TouchEventPhase: String {
        case unknown = "MouseInteractions.unknown"
        case start   = "MouseInteractions.TouchStart"
        case move    = "MouseInteractions.TouchMove"
        case end     = "MouseInteractions.TouchEnd"
    }
    
    init(timestamp: Date, touchId: Int, x: Float, y: Float, phase: TouchEventPhase) {
        super.init(type: .touch,
                   timestamp: timestamp,
                   data: [
                    "source": phase == .move ? 7 : 2,
                    "id": 0,
                    "pointerId": touchId,
                    "type": phase.rawValue,
                    "x": x,
                    "y": y,
                    "pointerType": 2
                   ])
    }
}
