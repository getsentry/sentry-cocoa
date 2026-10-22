internal import _SentryPrivate

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import Foundation

/// Adds breadcrumbs when the hinge of a foldable device, such as iPhone Duo, moves between the
/// closed, partially open, and fully open states.
final class SentryHingeBreadcrumbs {
    private weak var delegate: SentryBreadcrumbDelegate?
    private let hingeObserver: SentryHingeObserving

    /// The last observed hinge status, used to only add breadcrumbs for status transitions.
    /// Only accessed on the main thread, where hinge updates are delivered.
    private var lastHingeStatus: SentryHingeStatus?

    init(hingeObserver: SentryHingeObserving) {
        self.hingeObserver = hingeObserver
    }

    func start(with delegate: SentryBreadcrumbDelegate) {
        self.delegate = delegate
        hingeObserver.start { [weak self] hingeState in
            self?.hingeStateChanged(hingeState)
        }
    }

    func stop() {
        hingeObserver.stop()
        delegate = nil
    }

    /**
     * Angle-only updates are ignored, because the hinge reports them continuously while the device
     * is being folded. The first observed status only seeds the comparison, because it describes
     * the current posture rather than a change.
     */
    private func hingeStateChanged(_ hingeState: SentryHingeState) {
        guard hingeState.status != .unknown else {
            SentrySDKLog.debug("Hinge status is unknown. Won't create hinge state breadcrumb.")
            return
        }

        let previousStatus = lastHingeStatus
        lastHingeStatus = hingeState.status

        guard let previousStatus, previousStatus != hingeState.status else {
            return
        }

        let crumb = Breadcrumb(level: .info, category: "device.event")
        crumb.type = "system"
        crumb.setData(value: "HINGE_STATE_CHANGE", key: "action")
        crumb.setData(value: hingeState.status.breadcrumbValue, key: "status")
        crumb.setData(value: previousStatus.breadcrumbValue, key: "previous_status")
        // The angle is reported in radians, so we convert it to degrees for the breadcrumb.
        crumb.setData(value: Int((hingeState.angle * 180 / .pi).rounded()), key: "angle_degrees")
        delegate?.add(crumb)
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
