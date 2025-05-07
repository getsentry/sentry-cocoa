import Foundation
import Sentry

public extension Span {
    /// If span is a transaction it has a list of children
    func children() -> [Span]? {
        let sel = NSSelectorFromString("children")
        if !self.responds(to: sel) {
            return nil
        }

        return self.perform(sel)?.takeUnretainedValue() as? [Span]
    }

    /// If span is a transaction it has a rootSpan
    func rootSpan() -> Span? {
        let sel = NSSelectorFromString("rootSpan")
        if !self.responds(to: sel) {
            return nil
        }

        return self.perform(sel)?.takeUnretainedValue() as? Span
    }
}
