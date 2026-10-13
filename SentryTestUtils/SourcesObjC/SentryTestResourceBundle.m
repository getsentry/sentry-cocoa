#import "SentryTestResourceBundle.h"

#if SWIFT_PACKAGE
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
