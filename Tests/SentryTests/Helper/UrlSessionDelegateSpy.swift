import Foundation

class UrlSessionDelegateSpy: NSObject, URLSessionDelegate {
    var delegateCallback: () -> Void = {}

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        delegateCallback()
    }
}
