import Foundation

@objcMembers
public class SentrySpanOperation: NSObject {
    static let appLifecycle = "app.lifecycle"

    static let coredataFetchOperation = "db.sql.query"
    static let coredataSaveOperation = "db.sql.transaction"

    static let fileRead = "file.read"
    static let fileWrite = "file.write"

    static let networkRequestOperation = "http.client"

    static let uiAction = "ui.action"
    static let uiActionClick = "ui.action.click"

    /// Needs to be public to be accessible from `SentrySwiftUI`
    public static let uiLoad = "ui.load"
    static let uiLoadInitialDisplay = "ui.load.initial_display"
    static let uiLoadFullDisplay = "ui.load.full_display"
}
