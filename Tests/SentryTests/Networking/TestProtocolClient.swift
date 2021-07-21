import Foundation

class TestProtocolClient: NSObject, URLProtocolClient {
    
    var testCallback: ((String, [String: Any?]) -> Void)?
    
    func urlProtocol(_ callingProtocol: URLProtocol, wasRedirectedTo request: URLRequest, redirectResponse: URLResponse) {
        testCallback?("urlProtocol:wasRedirectedTo:redirectResponse:",
                      ["urlProtocol": callingProtocol,
                       "wasRedirectedTo": request,
                       "redirectResponse": redirectResponse])
    }
    
    func urlProtocol(_ callingProtocol: URLProtocol, cachedResponseIsValid cachedResponse: CachedURLResponse) {
        testCallback?("urlProtocol:cachedResponseIsValid:",
                      ["urlProtocol": callingProtocol,
                       "cachedResponseIsValid": cachedResponse])
    }
    
    func urlProtocol(_ callingProtocol: URLProtocol, didReceive response: URLResponse, cacheStoragePolicy policy: URLCache.StoragePolicy) {
        testCallback?("urlProtocol:didReceive:cacheStoragePolicy:",
                      ["urlProtocol": callingProtocol,
                       "didReceive": response,
                       "cacheStoragePolicy": policy])
    }
    
    func urlProtocol(_ callingProtocol: URLProtocol, didLoad data: Data) {
        testCallback?("urlProtocol:didLoad:",
                      ["urlProtocol": callingProtocol,
                       "didLoad": data])
    }
    
    func urlProtocolDidFinishLoading(_ callingProtocol: URLProtocol) {
        testCallback?("urlProtocolDidFinishLoading:",
                      ["urlProtocol": callingProtocol])
    }
    
    func urlProtocol(_ callingProtocol: URLProtocol, didFailWithError error: Error) {
        testCallback?("urlProtocol:didFailWithError:",
                      ["urlProtocol": callingProtocol,
                       "didFailWithError": error])
    }
    
    func urlProtocol(_ callingProtocol: URLProtocol, didReceive challenge: URLAuthenticationChallenge) {
        testCallback?("urlProtocol:didReceive:",
                      ["urlProtocol": callingProtocol,
                       "didReceive": challenge])
    }
    
    func urlProtocol(_ callingProtocol: URLProtocol, didCancel challenge: URLAuthenticationChallenge) {
        testCallback?("urlProtocol:didCancel:",
                      ["urlProtocol": callingProtocol,
                       "didCancel": challenge])
    }
    
}
