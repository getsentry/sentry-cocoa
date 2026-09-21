#if os(iOS) || os(macOS) || os(visionOS)
extension Event {
    // swiftlint:disable:next missing_docs
    @objc @_spi(Private) public func isMetricKitEvent() -> Bool {
        guard let mechanism = exceptions?.first?.mechanism, exceptions?.count == 1 else {
            return false
        }

        return SentryMXManager.Diagnostic.all.contains { $0.mechanism == mechanism.type }
    }
}
#endif
