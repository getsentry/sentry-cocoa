import Foundation

public class TestRequestManager: NSObject, RequestManager {
    
    private var nextResponse : HTTPURLResponse?
    public var isReady: Bool
    public var requests : [URLRequest] = []
    
    public required init(session: URLSession) {
        self.isReady = true
    }
    
    public func add( _ request: URLRequest, completionHandler: SentryRequestOperationFinished? = nil) {
        
        requests.append(request)
        
        if (nil != completionHandler) {
            let response = nextResponse ?? HTTPURLResponse(coder: NSCoder())
            completionHandler!(response, nil)
        }
    }
    
    public func cancelAllOperations() {
        
    }
    
    func returnResponse(response: HTTPURLResponse) {
        nextResponse = response
    }
}
