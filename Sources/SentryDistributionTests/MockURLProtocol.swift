import Foundation

final class MockURLProtocol: URLProtocol {
  override class func canInit(with request: URLRequest) -> Bool {
    true
  }
  
  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }
  
  static var startLoading: ((URLRequest) throws -> (URLResponse, Data))?
  
  override func startLoading() {
    guard let handler = Self.startLoading else {
      return
    }

    if let (response, data) = try? handler(request) {
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    }
  }
  
  override func stopLoading() { }
}
