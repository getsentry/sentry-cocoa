import Foundation

/**
 * For recording invocations of methods in a list in a thread safe manner.
 */
public class Invocations<T> {

    public init() {}
    
    private let queue = DispatchQueue(label: "Invocations", attributes: .concurrent)
    
    private var _invocations: [T] = []
    
    public var invocations: [T] {
        return queue.sync {
            return self._invocations
        }
    }
    
    public var count: Int {
        return queue.sync {
            return self._invocations.count
        }
    }
    
    public var first: T? {
        return queue.sync {
            return self._invocations.first
        }
    }
    
    public var last: T? {
        return queue.sync {
            return self._invocations.last
        }
    }
    
    public var isEmpty: Bool {
        return queue.sync {
            return self._invocations.isEmpty
        }
    }
    
    public func record(_ invocation: T) {
        queue.async(flags: .barrier) {
            self._invocations.append(invocation)
        }
    }
}
