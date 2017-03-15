//
//  RequestOperation.swift
//  Sentry
//
//  Created by Daniel Griesser on 21/12/2016.
//
//

import Foundation

class RequestOperation: AsynchronousOperation {
    
    var task: URLSessionTask?
    var request: URLRequest?
    
    init(session: URLSession, request: URLRequest, finished: SentryEndpointRequestFinished? = nil) {
        super.init()
        
        self.request = request
        #if swift(>=3.0)
        task = session.dataTask(with: request) { data, response, error in
            defer {
                self.completeOperation()
            }
            
            var success = false
            
            // Returns success if we have data and 200 response code
            if let data = data, let response = response as? HTTPURLResponse {
                Log.Debug.log("status = \(response.statusCode)")
                Log.Debug.log("response = \(NSString(data: data, encoding: String.Encoding.utf8.rawValue))")
                if response.statusCode == 429 {
                    Log.Error.log("Rate limit reached, event will be stored and sent later")
                }
                success = 200..<300 ~= response.statusCode
            }
            if let error = error {
                Log.Error.log("error = \(error)")
                
                success = false
            }
            
            finished?(success)
        }
        #else
        task = session.dataTaskWithRequest(request) { data, response, error in
            defer {
                self.completeOperation()
            }
            
            var success = false
            
            // Returns success if we have data and 200 response code
            if let data = data, let response = response as? NSHTTPURLResponse {
                Log.Debug.log("status = \(response.statusCode)")
                Log.Debug.log("response = \(NSString(data: data, encoding: NSUTF8StringEncoding))")
                if response.statusCode == 429 {
                    Log.Error.log("Rate limit reached, event will be stored and sent later")
                }
                success = 200..<300 ~= response.statusCode
            }
            if let error = error {
                Log.Error.log("error = \(error)")
                success = false
            }
            
            finished?(success)
        }
        #endif
    }
    
    override func cancel() {
        if let task = task {
            task.cancel()
        }
        super.cancel()
    }
    
    override func main() {
        if let task = task { task.resume() }
    }
    
}

#if swift(>=3.0)
class AsynchronousOperation: Operation {
    
    override public var isAsynchronous: Bool { return true }
    
    private let stateLock = NSLock()
    
    private var _executing: Bool = false
    override private(set) public var isExecuting: Bool {
        get {
            return stateLock.withCriticalScope { _executing }
        }
        set {
            willChangeValue(forKey: "isExecuting")
            stateLock.withCriticalScope { _executing = newValue }
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    private var _finished: Bool = false
    override private(set) public var isFinished: Bool {
        get {
            return stateLock.withCriticalScope { _finished }
        }
        set {
            willChangeValue(forKey: "isFinished")
            stateLock.withCriticalScope { _finished = newValue }
            didChangeValue(forKey: "isFinished")
        }
    }
    
    /// Complete the operation
    ///
    /// This will result in the appropriate KVN of isFinished and isExecuting
    public func completeOperation() {
        if isExecuting { _executing = false }
        if !isFinished { _finished = true }
    }
    
    override public func start() {
        if isCancelled {
            _finished = true
            return
        }
        
        _executing = true
        
        main()
    }
    
    override public func main() {
        fatalError("subclasses must override `main`")
    }
}
#else
public class AsynchronousOperation : NSOperation {
    
    override public var asynchronous: Bool { return true }
    
    private let stateLock = NSLock()
    
    private var _executing: Bool = false
    override private(set) public var executing: Bool {
        get {
            return stateLock.withCriticalScope { self._executing }
        }
        set {
            willChangeValueForKey("isExecuting")
            stateLock.withCriticalScope { self._executing = newValue }
            didChangeValueForKey("isExecuting")
        }
    }
    
    private var _finished: Bool = false
    override private(set) public var finished: Bool {
        get {
            return stateLock.withCriticalScope { self._finished }
        }
        set {
            willChangeValueForKey("isFinished")
            stateLock.withCriticalScope { self._finished = newValue }
            didChangeValueForKey("isFinished")
        }
    }
    
    /// Complete the operation
    ///
    /// This will result in the appropriate KVN of isFinished and isExecuting
    
    public func completeOperation() {
        if executing {
            executing = false
        }
        
        if !finished {
            finished = true
        }
    }
    
    override public func start() {
        if cancelled {
            finished = true
            return
        }
        
        executing = true
        
        main()
    }
    
    override public func main() {
        fatalError("subclasses must override `main`")
    }
}
#endif

extension NSLock {
    
    /// Perform closure within lock.
    ///
    /// An extension to `NSLock` to simplify executing critical code.
    ///
    /// - parameter block: The closure to be performed.
    
    func withCriticalScope<T>( block: (Void) -> T) -> T {
        lock()
        let value = block()
        unlock()
        return value
    }
}
