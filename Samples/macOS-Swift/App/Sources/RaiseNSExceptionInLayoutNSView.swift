import Foundation

import AppKit

class RaiseNSExceptionInLayoutNSView: NSView {
    override func layout() {
        let userInfo: [String: String] = ["user-info-key-1": "user-info-value-1", "user-info-key-2": "user-info-value-2"]
        let exception = NSException(name: NSExceptionName("NSException via NSException raise"), reason: "Raised NSException", userInfo: userInfo)
        exception.raise()
        super.layout()
    }
}
