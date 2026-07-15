// swiftlint:disable missing_docs
import Foundation

@objc(SentryRequestManager) @_spi(Private)
public protocol RequestManager: NSObjectProtocol {

    @objc var isReady: Bool { get }

    @objc(addRequest:completionHandler:)
    func add(_ request: URLRequest, completionHandler: SentryRequestOperationFinished?)
}
// swiftlint:enable missing_docs
