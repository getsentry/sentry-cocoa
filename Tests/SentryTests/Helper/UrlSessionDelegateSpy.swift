import Foundation

class UrlSessionDelegateSpy: NSObject, URLSessionDelegate {
    var delegateCallback: () -> Void = {}

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        delegateCallback()

        /*
         Fixes error in tests:

         2023-04-06 23:47:38.040259-0800 xctest[76215:8787183] [API] API MISUSE: NSURLSession delegate SentryTests.UrlSessionDelegateSpy: <SentryTests.UrlSessionDelegateSpy: 0x12b124d90> (0x12b124d90)
         2023-04-06 23:47:38.040521-0800 xctest[76215:8787183] [API] API MISUSE: didReceiveChallenge:completionHandler: completion handler not called
         */
        completionHandler(.performDefaultHandling, nil)
    }
}
