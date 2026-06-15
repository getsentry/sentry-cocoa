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

    func captureActivityReason(rootView: UIView) -> CaptureActivityReason? {
        if containsActiveInteraction(in: rootView) {
            return .interaction
        }

        if activeAnimationCount(in: rootView.layer, upTo: Self.activeAnimationThreshold) >= Self.activeAnimationThreshold {
            return .animation
        }

        return nil
    }

    private func containsActiveInteraction(in view: UIView) -> Bool {
        if let scrollView = view as? UIScrollView, scrollView.isDragging || scrollView.isDecelerating || scrollView.isTracking {
            return true
        }

        if let control = view as? UIControl, control.isTracking {
            return true
        }

        if view.gestureRecognizers?.contains(where: { $0.state == .began || $0.state == .changed }) == true {
            return true
        }

        return view.subviews.contains { containsActiveInteraction(in: $0) }
    }

    private func activeAnimationCount(in layer: CALayer, upTo limit: Int) -> Int {
        var count = layer.animationKeys()?.count ?? 0
        guard count < limit else { return count }

        for sublayer in layer.sublayers ?? [] {
            count += activeAnimationCount(in: sublayer, upTo: limit - count)
            if count >= limit {
                return count
            }
        }

        return count
    }
}

#endif
