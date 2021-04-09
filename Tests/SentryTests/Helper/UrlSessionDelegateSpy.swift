import Foundation

class UrlSessionDelegateSpy: NSObject, URLSessionDelegate {
    var urlSession_didReceive_completionHandler_called = false

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        urlSession_didReceive_completionHandler_called = true
    }
}
