import Foundation

import AppKit

/// For reproducing https://github.com/getsentry/sentry-cocoa/issues/5058
public class RaiseNSExceptionInLayoutNSView: NSView {

    public override func layout() {
        let userInfo: [String: String] = ["user-info-key-1": "user-info-value-1", "user-info-key-2": "user-info-value-2"]
        let exception = NSException(name: NSExceptionName("NSException via NSException raise within RaiseNSExceptionInLayoutNSView.layout"), reason: "Raised NSException", userInfo: userInfo)
        exception.raise()
        super.layout()
    }
}
