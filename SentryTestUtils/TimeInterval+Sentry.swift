public extension TimeInterval {
    func toNanoSeconds() -> UInt64 {
        return UInt64(self * Double(NSEC_PER_SEC))
    }
}

public extension UInt64 {
    func toTimeInterval() -> TimeInterval {
        return Double(self) / Double(NSEC_PER_SEC)
    }
}
