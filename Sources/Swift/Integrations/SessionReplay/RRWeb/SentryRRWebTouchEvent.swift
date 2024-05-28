import Foundation

@objcMembers
class SentryRRWebTouchEvent: SentryRRWebEvent {
    
    enum TouchEventPhase: Int {
        case unknown = 0
        case start   = 7
        case move    = 8
        case end     = 9
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
