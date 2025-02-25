import Foundation

@objcMembers @objc(SentryTraceOrigin)
class SentryTraceOrigin: NSObject {
    static let autoAppStart: NSString = "auto.app.start"
    static let autoAppStartProfile: NSString = "auto.app.start.profile"
    static let autoDBCoreData: NSString = "auto.db.core_data"
    static let autoHttpNSURLSession: NSString = "auto.http.ns_url_session"
    static let autoNSData: NSString = "auto.file.ns_data"
    static let autoUiEventTracker: NSString = "auto.ui.event_tracker"
    static let autoUITimeToDisplay: NSString = "auto.ui.time_to_display"
    static let autoUIViewController: NSString = "auto.ui.view_controller"
    static let manual: NSString = "manual"
    static let manualFileData: NSString = "manual.file.data"
    static let manualUITimeToDisplay: NSString = "manual.ui.time_to_display"
}
