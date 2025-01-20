import Foundation

@objcMembers @objc(SentryTraceOrigin)
class SentryTraceOrigin: NSObject {
    static let autoNSData = "auto.file.ns_data"
    static let manual = "manual"
    static let uiEventTracker = "auto.ui.event_tracker"
    static let autoAppStart = "auto.app.start"
    static let autoAppStartProfile = "auto.app.start.profile"
    static let autoDBCoreData = "auto.db.core_data"
    static let autoHttpNSURLSession = "auto.http.ns_url_session"
    static let autoUIViewController = "auto.ui.view_controller"
    static let autoUITimeToDisplay = "auto.ui.time_to_display"
    static let manualUITimeToDisplay = "manual.ui.time_to_display"
}
