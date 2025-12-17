import Foundation

@objc
public protocol SentryRedactOptions {
    var maskAllText: Bool { get }
    var maskAllImages: Bool { get }
    var maskedViewClasses: [AnyClass] { get }
    var unmaskedViewClasses: [AnyClass] { get }
    var viewTypesIgnoredFromSubtreeTraversal: Set<String> { get }
}

@objcMembers
@_spi(Private) public final class SentryRedactDefaultOptions: NSObject, SentryRedactOptions {
    public var maskAllText: Bool = true
    public var maskAllImages: Bool = true
    public var maskedViewClasses: [AnyClass] = []
    public var unmaskedViewClasses: [AnyClass] = []
    
    /// Default view types for which subtree traversal should be ignored.
    ///
    /// By default, includes `CameraUI.ChromeSwiftUIView` on iOS 26+ to avoid crashes
    /// when accessing `CameraUI.ModeLoupeLayer`.
    public var viewTypesIgnoredFromSubtreeTraversal: Set<String> {
        var defaults: Set<String> = []
        // CameraUI.ChromeSwiftUIView is a special case because it contains layers which can not be iterated due to this error:
        //   Fatal error: Use of unimplemented initializer 'init(layer:)' for class 'CameraUI.ModeLoupeLayer'
        #if os(iOS)
        if #available(iOS 26.0, *) {
            defaults.insert("CameraUI.ChromeSwiftUIView")
        }
        #endif // os(iOS)
        return defaults
    }
}
