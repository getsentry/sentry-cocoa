//
//  RequestManager.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 21/12/2016.
//
//

import UIKit

internal class RequestManager {
    
    let queue: OperationQueue = {
        let _queue = OperationQueue()
        _queue.name = "io.sentry.RequestManager.OperationQueue"
        _queue.maxConcurrentOperationCount = 3
        return _queue
    }()
    
    var isQueueReady: Bool {
        return queue.operationCount <= 1 // We always have at least on operation in the queue when calling this
    }
    
    let session: URLSession
    
    init(session: URLSession) {
        self.session = session
    }
    
    func addRequest(_ request: URLRequest, finished: SentryEndpointRequestFinished? = nil) {
        let operation = RequestOperation(session: session, request: request, finished: { success in
            finished?(success)
        })
        
        guard !queue.operations.contains(operation) else {
            return
        }
        
        queue.addOperation(operation)
    }
    
}
