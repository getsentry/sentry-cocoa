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

    // Call this off the main thread; the sole caller runs it on a background queue. (These `_dyld_*`
    // calls take the dyld loader read lock that image load/unload contends, and the superclass walk
    // over every class takes a few ms — neither belongs on the main thread.)
    //
    // Known limitation (Finding 1 in REVIEW-PR-8457.md; tracked in HANDOFF-subclassfinder-fix.md):
    // if the target image is unloaded concurrently, working with its classes can crash. We accept this
    // as a narrow, documented limitation rather than guarding against it. Why it's narrow and why a
    // read-side fix wouldn't help:
    //
    // - Reachable only for a concurrently-unloaded `MH_BUNDLE` (a `dlopen`-able `.bundle` plugin). The
    //   default `inAppInclude` is the main executable (`MH_EXECUTE`), which never unloads; frameworks
    //   and embedded dylibs (`MH_DYLIB`) don't unload once they register ObjC/Swift classes (the
    //   runtime keeps pointers into them). So the common cases are safe. Only an app that `dlopen`s an
    //   ObjC/VC-containing bundle, points the SDK at it, and `dlclose`s it mid-flight is exposed.
    // - A read-time fix (holding a lock across the read, pinning the image for the `getsectiondata`
    //   call, coordinating via `SentryBinaryImageCache`) does NOT close this. `classes(inSection:)`
    //   returns raw class pointers that live in the image's `__DATA`/`__DATA_CONST`; they are used
    //   AFTER this function returns — `SentrySubClassFinder` walks `class_getSuperclass` on a
    //   background queue, then swizzles on the main queue. If the image unloads anywhere in that
    //   window the class pointers dangle and crash, outside any read scope. The only true fixes would
    //   prevent unload for the lifetime of every swizzle (effectively forever) or refuse to instrument
    //   unloadable images; both were considered and declined.
    //
    // The same unpinned `_dyld_get_image_header` + `getsectiondata` read is used elsewhere in the SDK
    // (SentryCrashCxaThrowSwapper.c, SentryCrashDynamicLinker.c).
    //
    // Only supported on iOS, tvOS, and visionOS. It reads `mach_header_64` via `getsectiondata`, so
    // we gate it to 64-bit architectures: every slice these platforms ship (`arm64`/`arm64e`
    // devices, `arm64`/`x86_64` simulators), excluding the 32-bit watchOS device slices
    // (`arm64_32`, `armv7k`) where the 64-bit header layout doesn't apply.
#if (os(iOS) || os(tvOS) || os(visionOS)) && (arch(arm64) || arch(x86_64))
    @_spi(Private)
    public func classes(forImage image: UnsafePointer<CChar>) -> [AnyClass] {
        // We read `_dyld_image_count` once instead of per iteration (unlike the CxaThrowSwapper):
        // we're searching for one already-loaded image by name, so images added while iterating can't
        // be our target and re-reading the count each iteration would gain nothing. (This is only a
        // loop-bound choice, not a safety property — the concurrent-unload limitation above is
        // unaffected either way.) An index that goes out of range after an unload returns nil below.
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
            // Known limitation (Finding 2 in REVIEW-PR-8457.md; tracked in HANDOFF-subclassfinder-fix.md):
            // an Objective-C future class can have a view-controller superclass, pass
            // `SentrySubClassFinder`'s `class_getSuperclass` filter, and reach the swizzler as a raw
            // pointer that differs from the live class — bypassing `SentrySwizzle`'s class-identity
            // dedup (objc4 only forbids a future class from being *completed by a Swift class*, not from
            // having an ObjC view-controller superclass). Re-resolving by name via `NSClassFromString`
            // is not an option: it realizes the class (the GH-8152 crash this change removed) and can
            // pick a same-named class from another image.
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
