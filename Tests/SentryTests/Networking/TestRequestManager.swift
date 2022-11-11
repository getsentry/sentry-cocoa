import Foundation

// Even if we don't run this test below OSX 10.12 we expect the actual
// implementation to be thread safe.
@available(OSX 10.12, *)
public class TestRequestManager: NSObject, RequestManager {
    
    private var nextResponse: () -> HTTPURLResponse? = { return nil }
    var nextError: NSError?
    public var isReady: Bool
    
    var requests = Invocations<URLRequest>()
    
    private let queue = DispatchQueue(label: "TestRequestManager", qos: .background, attributes: [])
    private let group = DispatchGroup()
    
    public required init(session: URLSession) {
        self.isReady = true
    }
    
    var responseDelay = 0.0
    public func add( _ request: URLRequest, completionHandler: SentryRequestOperationFinished? = nil) {
        
        requests.record(request)
        
        let response = self.nextResponse()
        let error = self.nextError
        group.enter()
        queue.asyncAfter(deadline: .now() + responseDelay, execute: {
            if let handler = completionHandler {
                handler(response, error)
            }
            self.group.leave()
        })
    }
    
    public func waitForAllRequests() {
        group.waitWithTimeout()
    }
    
    func returnResponse(response: HTTPURLResponse?) {
        nextResponse = { return response }
    }
    
    func returnResponse(response: @escaping () -> HTTPURLResponse?) {
        nextResponse = response
    }
    
}
