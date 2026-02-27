import Foundation

// swiftlint:disable missing_docs

/// A storage class to hold the data associated with a single profiler sample.
@objcMembers
@_spi(Private) public final class SentrySample: NSObject {
    public var absoluteTimestamp: UInt64 = 0
    public var absoluteNSDateInterval: TimeInterval = 0
    public var stackIndex: NSNumber = NSNumber(value: 0)
    public var threadID: UInt64 = 0
    public var queueAddress: String?
}

// swiftlint:enable missing_docs
