import Foundation

// Even if we don't run this test below OSX 10.12 we expect the actual
// implementation to be thread safe.
@available(OSX 10.12, *)
public class TestRequestManager: NSObject, RequestManager {
    
    private var nextResponse : () -> HTTPURLResponse? = { return nil }
    public var isReady: Bool
    public var requests: [URLRequest] = []
    
    private let queue = DispatchQueue(label: "TestRequestManager", qos: .background, attributes: [])
    private let group = DispatchGroup()
    
    public required init(session: URLSession) {
        self.isReady = true
    }
    
    var responseDelay = 0.0
    public func add( _ request: URLRequest, completionHandler: SentryRequestOperationFinished? = nil) {
        
        requests.append(request)
        
        let response = self.nextResponse()
        group.enter()
        queue.asyncAfter(deadline: .now() + responseDelay, execute: {
            if let handler = completionHandler {
                handler(response, nil)
            }
            self.group.leave()
        })
    }
    
    public func waitForAllRequests() {
        group.waitWithTimeout()
    }
    
    public func cancelAllOperations() {
        
    }
    
    func returnResponse(response: HTTPURLResponse?) {
        nextResponse = { return response }
    }
    
    func returnResponse(response: @escaping () -> HTTPURLResponse?) {
        nextResponse = response
    }
}
