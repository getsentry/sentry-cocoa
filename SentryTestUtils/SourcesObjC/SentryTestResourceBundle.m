#import "SentryTestResourceBundle.h"

// Native SwiftPM pre-includes the accessor; Xcode requires an explicit import.
#if SWIFT_PACKAGE && !defined(SWIFTPM_MODULE_BUNDLE)
#    import "resource_bundle_accessor.h"
#endif

NSBundle *
SentryTestResourceBundle(Class testClass)
{
#if SWIFT_PACKAGE
    return SWIFTPM_MODULE_BUNDLE;
#else
    return [NSBundle bundleForClass:testClass];
#endif
}
