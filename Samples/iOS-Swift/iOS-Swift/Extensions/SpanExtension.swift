import Foundation
import Sentry

extension Span {
    
    //If span is a transaction it has a list of children
    func children() -> [Span]? {
        let sel = NSSelectorFromString("children")
        if !self.responds(to: sel) {
            return nil
        }
                
        let children = (self.perform(sel)?.takeUnretainedValue() as? NSSet)?.allObjects as? NSArray
        
        if children == nil {
            return nil
        }
        
        var result = [Span]()
        
        children?.forEach({
            if let span = $0 as? Span {
                result.append(span)
            }
        })
        
        return result
    }
    
    //If span is a transaction it has a rootSpan
    func rootSpan() -> Span? {
        let sel = NSSelectorFromString("rootSpan")
        if !self.responds(to: sel) {
            return nil
        }
                
        return self.perform(sel)?.takeUnretainedValue() as? Span
    }
}
