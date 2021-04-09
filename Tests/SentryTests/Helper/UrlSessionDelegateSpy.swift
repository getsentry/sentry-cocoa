import Foundation

class UrlSessionDelegateSpy: NSObject, URLSessionDelegate {
    var delegateCalled = false

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        delegateCalled = true
    }
}
