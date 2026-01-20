// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

@_spi(Private) @objc public final class SentryANRTracker: NSObject {
    
    let helper: SentryANRTrackerInternalProtocol
    var mapping = [ObjectIdentifier: DelegateWrapper]()
    
    init(helper: SentryANRTrackerInternalProtocol) {
        self.helper = helper
    }
    
    // Since this is public to ObjC it can only use parameters defined in Swift
    // We have to convert the Swift type to the internal ObjC type.
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

final class DelegateWrapper: NSObject, SentryANRTrackerInternalDelegate {
    func anrDetected(_ type: SentryANRTypeInternal) {
        helper?.anrDetected(type: SentryANRType.fromInternal(internal: type))
    }
    
    func anrStopped(_ result: SentryANRStoppedResultInternal?) {
        helper?.anrStopped(result: result.map { SentryANRStoppedResult(minDuration: $0.minDuration, maxDuration: $0.maxDuration ) })
    }
    
    weak var helper: SentryANRTrackerDelegate?
    
    init(helper: SentryANRTrackerDelegate) {
        self.helper = helper
    }
}

extension SentryANRType {
    static func fromInternal(internal: SentryANRTypeInternal) -> SentryANRType {
        switch `internal` {
        case SentryANRTypeInternal.fatalFullyBlocking:
            return .fatalFullyBlocking
        case SentryANRTypeInternal.fatalNonFullyBlocking:
            return .fatalNonFullyBlocking
        case SentryANRTypeInternal.fullyBlocking:
            return .fullyBlocking
        case SentryANRTypeInternal.nonFullyBlocking:
            return .nonFullyBlocking
        case SentryANRTypeInternal.unknown:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
}

// The V1/V2 tracker will conform to this
protocol SentryANRTrackerInternalProtocol {
    // The types of this protocol must be defined in ObjC since it is conformed to by
    // classes defined in ObjC.
    func addListener(_ listender: SentryANRTrackerInternalDelegate)
    func removeListener(_ listener: SentryANRTrackerInternalDelegate)
    
    /// Only used for tests.
    func clear()
}
// swiftlint:enable missing_docs
