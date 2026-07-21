// swiftlint:disable missing_docs
import Foundation
import MachO
import ObjectiveC.runtime

@objc @_spi(Private)
public final class SentryDefaultObjCRuntimeWrapper: NSObject, SentryObjCRuntimeWrapper {
    @_spi(Private)
    public func copyClassNamesForImage(_ image: UnsafePointer<CChar>, _ outCount: UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<UnsafePointer<CChar>>? {
        return objc_copyClassNamesForImage(image, outCount)
    }

    @_spi(Private)
    public func classGetImageName(_ cls: AnyClass) -> UnsafePointer<CChar>? {
        return class_getImageName(cls)
    }

    // Only supported on iOS, tvOS, and visionOS, matching `SentrySubClassFinder`, its only caller.
    // It reads `mach_header_64` via `getsectiondata`, so we gate it to 64-bit architectures. This
    // covers every slice these platforms ship (`arm64`/`arm64e` devices, `arm64`/`x86_64`
    // simulators) and excludes the 32-bit watchOS device slices (`arm64_32`, `armv7k`), where the
    // 64-bit header layout doesn't apply.
#if (os(iOS) || os(tvOS) || os(visionOS)) && (arch(arm64) || arch(x86_64))
    @_spi(Private)
    public func classes(forImage image: UnsafePointer<CChar>) -> [AnyClass] {
        let imageName = String(cString: image)
        for index in 0..<_dyld_image_count() {
            guard let cName = _dyld_get_image_name(index), String(cString: cName) == imageName else {
                continue
            }
            guard let header = _dyld_get_image_header(index) else {
                return []
            }

            // Read the class pointers from the image's `__objc_classlist` section (`__DATA_CONST` on
            // modern binaries, `__DATA` on older ones). dyld binds these pointers at load time, but
            // the classes aren't realized, so callers can inspect them without running class
            // initialization. This is why `SentrySubClassFinder` uses this instead of NSClassFromString.
            var size: UInt = 0
            let section = header.withMemoryRebound(to: mach_header_64.self, capacity: 1) { header in
                getsectiondata(header, "__DATA_CONST", "__objc_classlist", &size)
                    ?? getsectiondata(header, "__DATA", "__objc_classlist", &size)
            }
            guard let section else {
                return []
            }

            let count = Int(size) / MemoryLayout<UnsafeRawPointer>.size
            return section.withMemoryRebound(to: UnsafeRawPointer.self, capacity: count) { classes in
                (0..<count).map { unsafeBitCast(classes[$0], to: AnyClass.self) }
            }
        }

        return []
    }
#endif
}
// swiftlint:enable missing_docs
