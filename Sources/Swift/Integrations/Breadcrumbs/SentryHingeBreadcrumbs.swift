internal import _SentryPrivate

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import Foundation

/// Adds breadcrumbs when the hinge of a foldable device, such as iPhone Duo, opens or closes.
final class SentryHingeBreadcrumbs {
    /// The hinge has to move at least this far, in radians, since the last breadcrumb before a
    /// new breadcrumb is added. 45 degrees keeps the trail short while the device is being folded.
    static let reportingThreshold = Double.pi / 4

    private weak var delegate: SentryBreadcrumbDelegate?
    private let hingeObserver: SentryHingeObserving
    private var observerToken: SentryHingeObserverToken?

    /// The hinge state at the last breadcrumb, or the first observed state before any breadcrumb.
    /// Only accessed on the main thread, where hinge updates are delivered.
    private var lastReportedState: SentryHingeState?

    init(hingeObserver: SentryHingeObserving) {
        self.hingeObserver = hingeObserver
    }

    func start(with delegate: SentryBreadcrumbDelegate) {
        self.delegate = delegate
        guard observerToken == nil else {
            return
        }
        observerToken = hingeObserver.addObserver { [weak self] hingeState in
            self?.hingeStateChanged(hingeState)
        }
    }

    func stop() {
        if let observerToken {
            hingeObserver.removeObserver(token: observerToken)
        }
        observerToken = nil
        delegate = nil
        lastReportedState = nil
    }

    /**
     * The hinge reports angle updates continuously while the device is being folded, so a
     * breadcrumb is only added once the hinge moved at least `reportingThreshold` away from the
     * angle of the last breadcrumb, or once it reaches the fully closed or fully open position.
     * The first observed state only seeds the comparison, because it describes the current
     * posture rather than a movement.
     */
    private func hingeStateChanged(_ hingeState: SentryHingeState) {
        guard let delegate else {
            return
        }
        guard hingeState.status != .unknown else {
            SentrySDKLog.debug("Hinge status is unknown. Won't create hinge breadcrumb.")
            return
        }

        guard let lastReportedState else {
            lastReportedState = hingeState
            return
        }

        let isEndPosition = hingeState.status == .closed || hingeState.status == .fullyOpen
        if isEndPosition && hingeState.status == lastReportedState.status {
            // The hinge can report an end position before its angle settles. The position was
            // already reported, so only track the settled angle for the next movement.
            self.lastReportedState = hingeState
            return
        }

        let angleDelta = hingeState.angle - lastReportedState.angle
        let reachedEndPosition = isEndPosition && hingeState.status != lastReportedState.status
        guard reachedEndPosition || abs(angleDelta) >= Self.reportingThreshold else {
            return
        }
        self.lastReportedState = hingeState

        // The end positions define the direction on their own, which also covers the case of an
        // end position being reached with a negligible angle change.
        let direction: String
        switch hingeState.status {
        case .closed:
            direction = "closing"
        case .fullyOpen:
            direction = "opening"
        case .partiallyOpen, .unknown:
            direction = angleDelta > 0 ? "opening" : "closing"
        }

        let crumb = Breadcrumb(level: .info, category: "device.event")
        crumb.type = "system"
        crumb.setData(value: "HINGE_STATE_CHANGE", key: "action")
        crumb.setData(value: direction, key: "direction")
        crumb.setData(value: hingeState.status.breadcrumbValue, key: "status")
        crumb.setData(value: lastReportedState.status.breadcrumbValue, key: "previous_status")
        delegate.add(crumb)
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
