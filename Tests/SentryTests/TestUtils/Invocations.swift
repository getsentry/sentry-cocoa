import Foundation

/**
 * For recording invocations of methods in a list in a thread safe manner.
 */
class Invocations<T> {
    
    private let queue = DispatchQueue(label: "Invocations", attributes: .concurrent)
    
    private var _invocations: [T] = []
    
    var invocations: [T] {
        return queue.sync {
            return self._invocations
        }
    }
    
    var count: Int {
        return queue.sync {
            return self._invocations.count
        }
    }
    
    var first: T? {
        return queue.sync {
            return self._invocations.first
        }
    }
    
    var last: T? {
        return queue.sync {
            return self._invocations.last
        }
    }
    
    var isEmpty: Bool {
        return queue.sync {
            return self._invocations.isEmpty
        }
    }
    
    func record(_ invocation: T) {
        queue.async(flags: .barrier) {
            self._invocations.append(invocation)
        }
    }
}
