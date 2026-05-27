import Foundation

@objc(SentryObjCInvocations)
public final class ObjCInvocations: NSObject {
    private let inner = Invocations<NSDictionary>()

    @objc public var count: Int { inner.count }
    @objc public var first: NSDictionary? { inner.first }
    @objc public var last: NSDictionary? { inner.last }
    @objc public var isEmpty: Bool { inner.isEmpty }
    @objc public var invocations: [NSDictionary] { inner.invocations }

    @objc public func record(_ invocation: NSDictionary) {
        inner.record(invocation)
    }

    @objc public func removeAll() {
        inner.removeAll()
    }
}
