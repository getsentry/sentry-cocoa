import Foundation

///
/// Use this protocol to customize the name used in the automatic
/// UIViewController performance tracker.
///
@objc
public protocol SentryUIViewControllerDescriptor: NSObjectProtocol {

    /// The custom name of the UIViewController
    /// that will be used for the transaction name.
    var sentryName: String { get }
}
