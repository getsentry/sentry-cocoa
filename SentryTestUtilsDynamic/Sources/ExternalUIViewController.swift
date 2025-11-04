import Foundation

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
import UIKit

//This class is used to test swizzling of view controllers in external libs
public class ExternalUIViewController: UIViewController {
}

#endif
