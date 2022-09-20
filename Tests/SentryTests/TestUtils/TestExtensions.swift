import Foundation

extension TimeInterval {
    func toNanoSeconds() -> UInt64 {
        return UInt64(self * Double(NSEC_PER_SEC))
    }
}

extension UInt64 {
    func toTimeInterval() -> TimeInterval {
        return Double(self) / Double(NSEC_PER_SEC)
    }
}
