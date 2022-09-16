import Foundation

/**
 * For recording invocations of methods in a list in a thread safe manner.
 */
class Invocations<T> {
    private let queue = DispatchQueue(label: "Invocations", attributes: .concurrent)
    private var _invocations = NSMutableArray()

    var invocations: [T] {
        return queue.sync {
            return self._invocations as! [T]
        }
    }

    var count: Int {
        return queue.sync {
            return self._invocations.count
        }
    }

    var first: T? {
        return queue.sync {
            return self._invocations.firstObject as? T
        }
    }

    var last: T? {
        return queue.sync {
            return self._invocations.lastObject as? T
        }
    }

    var isEmpty: Bool {
        return queue.sync {
            return self._invocations.count == 0
        }
    }

    func record(_ invocation: T) {
        queue.async(flags: .barrier) {
            self._invocations.add(invocation)
        }
    }
}
