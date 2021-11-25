import Foundation
import Sentry

class SpanObserver: NSObject {

    let span: Span
    private var callbacks: [String: () -> Void] = [:]
    
    init(span: Span) {
        self.span = span
    }
    
    deinit {
        for key in callbacks.keys {
            removeSpanObserver(forKeyPath: key)
        }
    }
    
    func performOnFinish(callback : @escaping () -> Void) {
        addSpanObserver(forKeyPath: "timestamp", callback: callback)
    }
    
    func releaseOnFinish() {
        if callbacks["timestamp"] != nil {
            removeSpanObserver(forKeyPath: "timestamp")
        }
    }
    
    func addSpanObserver(forKeyPath keyPath: String, callback : @escaping () -> Void) {
        callbacks[keyPath] = callback
        (span as? NSObject)?.addObserver(self, forKeyPath: keyPath, options: .new, context: nil)
    }
    
    func removeSpanObserver(forKeyPath keyPath: String) {
        (span as? NSObject)?.removeObserver(self, forKeyPath: keyPath)
        callbacks.removeValue(forKey: keyPath)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let key = keyPath else { return }
        
        guard let callback = callbacks[key] else { return }
        
        callback()
    }
    
}
