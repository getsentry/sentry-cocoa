import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/// Inspects the view hierarchy to detect ongoing activity (user interactions or animations)
/// that should influence when ``SentrySessionReplay`` captures the next screenshot.
final class SentrySessionReplayCaptureGuard {
    private static let activeAnimationThreshold = 4

    enum CaptureActivityReason {
        case interaction
        case animation
    }

    func captureActivityReason(rootView: UIView, options: SentryRedactOptions) -> CaptureActivityReason? {
        if containsActiveInteraction(in: rootView, options: options) {
            return .interaction
        }

        if activeAnimationCount(in: rootView, options: options, upTo: Self.activeAnimationThreshold) >= Self.activeAnimationThreshold {
            return .animation
        }

        return nil
    }

    private func containsActiveInteraction(in view: UIView, options: SentryRedactOptions) -> Bool {
        return SentryViewSubtreeTraversal.traverse(view, options: options) { view in
            if let scrollView = view as? UIScrollView, scrollView.isDragging || scrollView.isDecelerating || scrollView.isTracking {
                return true
            }

            if let control = view as? UIControl, control.isTracking {
                return true
            }

            return view.gestureRecognizers?.contains(where: { $0.state == .began || $0.state == .changed }) == true
        }
    }

    private func activeAnimationCount(in view: UIView, options: SentryRedactOptions, upTo limit: Int) -> Int {
        var count = 0
        SentryViewSubtreeTraversal.traverse(view, options: options) { view in
            count += view.layer.animationKeys()?.count ?? 0
            return count >= limit
        }
        return count
    }
}

#endif
