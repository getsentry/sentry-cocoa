import Foundation

/// A wrapper class for a weak reference, which is handy when keeping a list
/// of objects with only weak references. For example, the invocations class
/// keeps track of method invocation arguments. You can use this class if
/// you don't want the invocations class to retain objects.
public class WeakReference<T: AnyObject> {
  weak var value: T?
  init (value: T) {
    self.value = value
  }
}
