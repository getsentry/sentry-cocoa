import Foundation

public class WeakReference<T: AnyObject> {
  weak var value: T?
  init (value: T) {
    self.value = value
  }
}
