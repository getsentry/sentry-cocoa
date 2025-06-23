@objc(SentryRequestManager)
@_spi(Private) public protocol RequestManager {
    
    var isReady: Bool { get }
    
    init(session: URLSession)

    @objc(addRequest:completionHandler:)
    func add(_ request: URLRequest, completionHandler: ((HTTPURLResponse?, Error?) -> Void)?)
}
