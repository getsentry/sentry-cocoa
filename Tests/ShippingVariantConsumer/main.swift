import Foundation
#if canImport(SentryWithoutUIKit)
import SentryWithoutUIKit
#else
import Sentry
#endif

// Reference an SDK symbol, but not the object file that defines this ObjC category.
// A static framework must retain it without -ObjC, -all_load or -force_load.
precondition(!SentrySDK.isEnabled)
precondition(NSData().responds(to: NSSelectorFromString("asInputStream")))
