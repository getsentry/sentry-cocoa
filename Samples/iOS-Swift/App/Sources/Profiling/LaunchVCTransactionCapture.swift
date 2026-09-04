import Foundation
import SentrySwift

final class LaunchVCTransactionCapture {
    static let shared = LaunchVCTransactionCapture()

    private let lock = NSLock()
    private var spans: [[String: String]] = []

    private init() {}

    func capture(_ span: Span) {
        let op = span.operation
        guard op == "ui.load" || op == "ui.load.initial_display" || op == "ui.load.full_display" else {
            return
        }

        let entry: [String: String] = [
            "operation": op,
            "description": span.spanDescription ?? "",
            "hasParent": span.parentSpanId != nil ? "true" : "false"
        ]

        lock.lock()
        spans.append(entry)
        lock.unlock()
    }

    func serialized() -> String {
        lock.lock()
        let snapshot = spans
        lock.unlock()

        guard !snapshot.isEmpty else { return "<empty>" }

        guard let data = try? JSONSerialization.data(withJSONObject: snapshot, options: .sortedKeys),
              let json = String(data: data, encoding: .utf8) else {
            return "<error>"
        }
        return json
    }
}
