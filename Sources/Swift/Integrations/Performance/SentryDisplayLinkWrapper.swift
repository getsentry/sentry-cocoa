// swiftlint:disable missing_docs
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT

import UIKit

/// A wrapper around DisplayLink for testability.
@_spi(Private) @objc public class SentryDisplayLinkWrapper: NSObject {
    
    var displayLink: CADisplayLink?

    @objc public var timestamp: CFTimeInterval {
        displayLink?.timestamp ?? 0
    }

    @objc public var targetTimestamp: CFTimeInterval {
        displayLink?.targetTimestamp ?? 0
    }

    @objc public func link(withTarget target: Any, selector sel: Selector) {
        displayLink = CADisplayLink(target: target, selector: sel)
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc public func invalidate() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc public func isRunning() -> Bool {
        !(displayLink?.isPaused ?? true)
    }
}

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
extension SentryDisplayLinkWrapper: SentryReplayDisplayLinkWrapper {}
#endif

#endif
// swiftlint:enable missing_docs
