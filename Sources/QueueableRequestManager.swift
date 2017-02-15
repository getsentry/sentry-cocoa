//
//  QueueableRequestManager.swift
//  Sentry
//
//  Created by Daniel Griesser on 26/01/2017.
//
//

class QueueableRequestManager: RequestManager {
    
    let queue: OperationQueue = {
        let _queue = OperationQueue()
        _queue.name = "io.sentry.QueueableRequestManager.OperationQueue"
        _queue.maxConcurrentOperationCount = 3
        return _queue
    }()
    
    var isReady: Bool {
        return queue.operationCount <= 1 // We always have at least one operation in the queue when calling this
    }
    
    let session: URLSession
    
    required init(session: URLSession) {
        self.session = session
    }
    
    func addRequest(_ request: URLRequest, finished: SentryEndpointRequestFinished? = nil) {
        let operation = RequestOperation(session: session, request: request, finished: { [weak self] success in
            if let operationCount = self?.queue.operationCount {
                Log.Debug.log("Queued requests: \(operationCount - 1)")
            }
            finished?(success)
        })
        queue.addOperation(operation)
    }
    
}
