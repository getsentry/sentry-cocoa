#if !SDK_V10
// swiftlint:disable missing_docs
import Foundation

// The V1/V2 tracker will conform to this
protocol SentryANRTrackerInternalProtocol {
    func addListener(_ listener: SentryANRTrackerDelegate)
    func removeListener(_ listener: SentryANRTrackerDelegate)

    /// Only used for tests.
    func clear()
}

@_spi(Private) @objc public final class SentryANRTracker: NSObject {

    let helper: SentryANRTrackerInternalProtocol
    var mapping = [ObjectIdentifier: DelegateWrapper]()

    init(helper: SentryANRTrackerInternalProtocol) {
        self.helper = helper
    }

    @objc(addListener:) public func add(listener: SentryANRTrackerDelegate) {
        // Remove entries that no longer have the weak reference
        mapping = mapping.filter { _, value in
            value.helper != nil
        }
        let wrapped = DelegateWrapper(helper: listener)
        mapping[ObjectIdentifier(listener)] = wrapped
        helper.addListener(wrapped)
    }

    @objc(removeListener:) public func remove(listener: SentryANRTrackerDelegate) {
        guard let mapped = mapping[ObjectIdentifier(listener)] else {
            return
        }
        helper.removeListener(mapped)
    }

    @objc public func clear() {
        helper.clear()
    }
}

// Keep a separate weak listener object so removal during the delegate's deinit does not
// pass the deallocating delegate through the tracker's Objective-C weak hash table.
final class DelegateWrapper: NSObject, SentryANRTrackerDelegate {
    func anrDetected(type: SentryANRType) {
        helper?.anrDetected(type: type)
    }

    func anrStopped(result: SentryANRStoppedResult?) {
        helper?.anrStopped(result: result)
    }

    weak var helper: SentryANRTrackerDelegate?

    init(helper: SentryANRTrackerDelegate) {
        self.helper = helper
    }
}
// swiftlint:enable missing_docs
#endif
