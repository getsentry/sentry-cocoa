import Foundation

@objcMembers
public class SentryTraceOrigin: NSObject {
    static let autoNSData = "auto.file.ns_data"
    static let manual = "manual"
    static let uiEventTracker = "auto.ui.event_tracker"
    static let autoAppStart = "auto.app.start"
    static let autoAppStartProfile = "auto.app.start.profile"
    static let autoDBCoreData = "auto.db.core_data"
    static let autoHttpNSURLSession = "auto.http.ns_url_session"
    static let autoUIViewController = "auto.ui.view_controller"
    static let autoUITimeToDisplay = "auto.ui.time_to_display"

    /// Needs to be public to be accessible from `SentrySwiftUI`
    public static let autoUISwiftUI = "auto.ui.swift_ui"
    static let manualUITimeToDisplay = "manual.ui.time_to_display"
}
