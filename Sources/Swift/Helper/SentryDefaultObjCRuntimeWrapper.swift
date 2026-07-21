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

    // IMPORTANT: Call this off the main thread. `_dyld_get_image_header` and `_dyld_get_image_name`
    // acquire the dyld loader read lock, which every image load/unload (for example `dlopen`)
    // contends, so calling this on the main thread risks blocking it.
    //
    // Only supported on iOS, tvOS, and visionOS. It reads `mach_header_64` via `getsectiondata`, so
    // we gate it to 64-bit architectures: every slice these platforms ship (`arm64`/`arm64e`
    // devices, `arm64`/`x86_64` simulators), excluding the 32-bit watchOS device slices
    // (`arm64_32`, `armv7k`) where the 64-bit header layout doesn't apply.
#if (os(iOS) || os(tvOS) || os(visionOS)) && (arch(arm64) || arch(x86_64))
    @_spi(Private)
    public func classes(forImage image: UnsafePointer<CChar>) -> [AnyClass] {
        // We read `_dyld_image_count` once instead of per iteration (unlike the CxaThrowSwapper): we
        // search for one already-loaded image, so images added while iterating aren't our target, and
        // stale indices from an unload just return nil below.
        for index in 0..<_dyld_image_count() {
            guard let cName = _dyld_get_image_name(index), strcmp(cName, image) == 0 else {
                continue
            }
            guard let header = _dyld_get_image_header(index) else {
                SentrySDKLog.warning("No header for image: \(String(cString: image)). Skipping class list.")
                return []
            }

            // Only treat the header as a `mach_header_64` if it actually is one. dyld hands us thin,
            // native-arch, in-memory slices, so this holds in practice; the check is defensive. It
            // also rejects a FAT header (`FAT_MAGIC`), which would otherwise be misread, so we skip
            // such an image instead of going off into the weeds. `magic` is the first field of both
            // `mach_header` and `mach_header_64`, so we can read it before rebinding.
            guard header.pointee.magic == MH_MAGIC_64 else {
                SentrySDKLog.warning("Header for image: \(String(cString: image)) isn't a mach_header_64. Skipping class list.")
                return []
            }

            // Read the class pointers from the image's `__objc_classlist` section (`__DATA_CONST` on
            // modern binaries, `__DATA` on older ones). dyld binds these pointers at load time, but
            // the classes aren't realized, so callers can inspect them without running class
            // initialization, unlike `NSClassFromString`.
            //
            // These are the raw, compiler-emitted pointers; we do NOT run objc4's `remapClass` over
            // them, so for a class objc4 remaps (a resolved future class from `objc_getFutureClass`,
            // or a weak-linked class with a missing superclass that it maps to nil) the entry here can
            // differ from the live runtime class or be a disavowed struct.
            //
            // KNOWN OPEN ISSUE (Finding 2 in REVIEW-PR-8457.md; see HANDOFF-subclassfinder-fix.md):
            // an Objective-C future class can have a view-controller superclass, pass
            // `SentrySubClassFinder`'s `class_getSuperclass` filter, and reach the swizzler as a raw
            // pointer that differs from the live class — bypassing `SentrySwizzle`'s class-identity
            // dedup. objc4 only forbids a future class from being *completed by a Swift class*, not
            // from having an ObjC view-controller superclass, so this is not merely theoretical.
            // This must be resolved before merge, and the fix must not reintroduce the GH-8152
            // realization crash: re-resolving by name via `NSClassFromString` realizes the class and
            // can pick a same-named class from another image, which is exactly what this change removed.
            var size: UInt = 0
            let section = header.withMemoryRebound(to: mach_header_64.self, capacity: 1) { header in
                getsectiondata(header, "__DATA_CONST", "__objc_classlist", &size)
                    ?? getsectiondata(header, "__DATA", "__objc_classlist", &size)
            }
            guard let section else {
                SentrySDKLog.debug("No __objc_classlist section for image: \(String(cString: image)).")
                return []
            }

            return Self.classes(inSection: section, size: size)
        }

        SentrySDKLog.debug("Image not found in loaded images: \(String(cString: image)).")
        return []
    }

    // Internal so tests can exercise the null-entry edge case, which a real dyld-loaded
    // `__objc_classlist` section can't be made to contain.
    static func classes(inSection section: UnsafeMutablePointer<UInt8>, size: UInt) -> [AnyClass] {
        // The section holds ObjC `Class _Nullable` pointers, so `AnyClass?` is their honest
        // Swift type: reading through it needs no unsafeBitCast, and a null entry (malformed
        // section) becomes `nil` and is skipped instead of producing an invalid `AnyClass`.
        let count = Int(size) / MemoryLayout<AnyClass?>.stride
        return section.withMemoryRebound(to: AnyClass?.self, capacity: count) { classes in
            UnsafeBufferPointer(start: classes, count: count).compactMap { $0 }
        }
    }
#endif
}
// swiftlint:enable missing_docs
