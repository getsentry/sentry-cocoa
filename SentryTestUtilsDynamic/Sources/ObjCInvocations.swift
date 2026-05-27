import Foundation

@objc(SentryObjCInvocations)
public final class ObjCInvocations: NSObject {

    private let queue = DispatchQueue(label: "ObjCInvocations")
    private var _invocations: [NSDictionary] = []

    @objc public var count: Int {
        queue.sync { _invocations.count }
    }

    @objc public var first: NSDictionary? {
        queue.sync { _invocations.first }
    }

    @objc public var last: NSDictionary? {
        queue.sync { _invocations.last }
    }

    @objc public var isEmpty: Bool {
        queue.sync { _invocations.isEmpty }
    }

    @objc public var invocations: [NSDictionary] {
        queue.sync { _invocations }
    }

    @objc public func record(_ invocation: NSDictionary) {
        queue.async { self._invocations.append(invocation) }
    }

    @objc public func removeAll() {
        queue.async { self._invocations.removeAll() }
    }
}
