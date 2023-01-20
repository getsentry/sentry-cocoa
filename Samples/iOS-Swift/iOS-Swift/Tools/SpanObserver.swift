import Foundation
import Sentry

class SpanObserver: NSObject {

    let span: SentrySpan
    private var callbacks: [String: (Span) -> Void] = [:]
    
    init(span: SentrySpan) {
        self.span = span
    }
    
    convenience init?(callback: @escaping (Span) -> Void) {
        guard let span = SentrySDK.span else { return nil }
        self.init(span: span)
        self.performOnFinish(callback: callback)
    }
    
    deinit {
        for key in callbacks.keys {
            removeSpanObserver(forKeyPath: key)
        }
    }
    
    func performOnFinish(callback: @escaping (Span) -> Void) {
        addSpanObserver(forKeyPath: "timestamp", callback: callback)
    }
    
    func releaseOnFinish() {
        if callbacks["timestamp"] != nil {
            removeSpanObserver(forKeyPath: "timestamp")
        }
    }
    
    func addSpanObserver(forKeyPath keyPath: String, callback: @escaping (Span) -> Void) {
        callbacks[keyPath] = callback
        //The given span may be a SentryTracer that wont respond to KVO. We need to get the root Span
        let spanToObserve = span.rootSpan() ?? span
        (spanToObserve as? NSObject)?.addObserver(self, forKeyPath: keyPath, options: .new, context: nil)
    }
    
    func removeSpanObserver(forKeyPath keyPath: String) {
        let spanToObserve = span.rootSpan() ?? span //see `addSpanObserver`
        (spanToObserve as? NSObject)?.removeObserver(self, forKeyPath: keyPath)
        callbacks.removeValue(forKey: keyPath)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let key = keyPath else { return }
        
        guard let callback = callbacks[key] else { return }
        
        callback(span)
    }
    
}
