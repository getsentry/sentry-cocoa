// swiftlint:disable missing_docs
import Foundation

@_spi(Private)
@objc(SentryRequestManager)
public protocol RequestManager: NSObjectProtocol {

    @objc var isReady: Bool { get }

    @objc(addRequest:completionHandler:)
    func add(_ request: URLRequest, completionHandler: SentryRequestOperationFinished?)
}
// swiftlint:enable missing_docs
