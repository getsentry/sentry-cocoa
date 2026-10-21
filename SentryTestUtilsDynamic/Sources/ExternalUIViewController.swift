import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/// This class is used to test swizzling of view controllers in external libs
public class ExternalUIViewController: UIViewController {
}

#endif
