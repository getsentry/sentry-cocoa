@_implementationOnly import _SentryPrivate

// swiftlint:disable missing_docs
@objc
@_spi(Private)
public protocol SentryBreadcrumbDelegate: NSObjectProtocol {
    @objc(addBreadcrumb:)
    func add(_ crumb: Breadcrumb)
}
// swiftlint:enable missing_docs
