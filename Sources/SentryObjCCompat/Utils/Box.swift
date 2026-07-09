// Indirection box for resilient value types stored as ivars in @objc wrapper classes.
//
// Under -enable-library-evolution (BUILD_LIBRARY_FOR_DISTRIBUTION), the Swift compiler
// treats cross-module value types (enums, structs) as resilient — their in-memory size
// is unknown at compile time. On x86_64, this forces the compiler to use runtime class
// realization (CMt) instead of emitting a static _OBJC_CLASS_$_ symbol, causing linker
// failures for consumers of the SentryObjC framework.
//
// Wrapping the resilient value in a class makes the stored property pointer-sized
// (always known), so the compiler can emit a static class layout on all architectures.
internal final class Box<T> {
    let value: T
    init(_ value: T) { self.value = value }
}
