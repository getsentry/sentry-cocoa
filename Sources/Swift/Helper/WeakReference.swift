import Foundation

/// A wrapper class for a weak reference, which is handy when keeping a list
/// of objects with only weak references. The wrapper is read via the Swift
/// `weak` runtime (`objc_loadWeak`), which is safe against concurrent
/// deallocation of the referenced object.
// swiftlint:disable:next missing_docs
@_spi(Private) public class WeakReference<T: AnyObject> {
    weak var value: T?

    init(value: T) {
        self.value = value
    }
}
