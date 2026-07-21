// swiftlint:disable missing_docs
import Foundation

@objc @_spi(Private)
public protocol SentryObjCRuntimeWrapper {
    @objc(copyClassNamesForImage:amount:)
    func copyClassNamesForImage(_ image: UnsafePointer<CChar>, _ outCount: UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<UnsafePointer<CChar>>?
    @objc(class_getImageName:)
    func classGetImageName(_ cls: AnyClass) -> UnsafePointer<CChar>?
    /// IMPORTANT: Call this off the main thread. `_dyld_get_image_header` and `_dyld_get_image_name`
    /// acquire the dyld loader read lock that every image load/unload contends, so calling it on the
    /// main thread risks blocking it.
    ///
    /// Returns the classes defined in the given image by reading its `__objc_classlist` section.
    /// The classes are not realized, so callers can inspect them (e.g. walk their superclass chain)
    /// without triggering class initialization.
    ///
    /// Only supported on iOS, tvOS, and visionOS. It relies on `getsectiondata` with `mach_header_64`,
    /// so it's gated to 64-bit architectures and excludes the 32-bit watchOS device slices
    /// (`arm64_32`, `armv7k`).
#if (os(iOS) || os(tvOS) || os(visionOS)) && (arch(arm64) || arch(x86_64))
    @objc(classesForImage:)
    func classes(forImage image: UnsafePointer<CChar>) -> [AnyClass]
#endif
}
// swiftlint:enable missing_docs
