// swiftlint:disable missing_docs
import Foundation

@objc @_spi(Private)
public protocol SentryObjCRuntimeWrapper {
    @objc(copyClassNamesForImage:amount:)
    func copyClassNamesForImage(_ image: UnsafePointer<CChar>, _ outCount: UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<UnsafePointer<CChar>>?
    @objc(class_getImageName:)
    func classGetImageName(_ cls: AnyClass) -> UnsafePointer<CChar>?
    /// Returns the classes defined in the given image by reading its `__objc_classlist` section.
    /// The classes are not realized, so callers can inspect them (e.g. walk their superclass chain)
    /// without triggering class initialization.
    @objc(classesForImage:)
    func classes(forImage image: UnsafePointer<CChar>) -> [AnyClass]
}
// swiftlint:enable missing_docs
