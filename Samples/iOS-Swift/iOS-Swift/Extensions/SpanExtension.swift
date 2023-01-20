import Foundation
import Sentry

extension Span {
    
    //If span is a transaction it has a list of children
    func children() -> [SentrySpan]? {
        let sel = NSSelectorFromString("children")
        if !self.responds(to: sel) {
            return nil
        }
                
        return self.perform(sel)?.takeUnretainedValue() as? [SentrySpan]
    }
    
    //If span is a transaction it has a rootSpan
    func rootSpan() -> SentrySpan? {
        let sel = NSSelectorFromString("rootSpan")
        if !self.responds(to: sel) {
            return nil
        }
                
        return self.perform(sel)?.takeUnretainedValue() as? Span
    }
}
