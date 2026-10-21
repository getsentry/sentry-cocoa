#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Shared SwiftPM fixture bundle, or the calling test's bundle in the Xcode project.
/// Pass the test class, not a helper class, to preserve Xcode's resource lookup.
FOUNDATION_EXPORT NSBundle *SentryTestResourceBundle(Class testClass)
    NS_SWIFT_NAME(sentryTestResourceBundle(for:));

NS_ASSUME_NONNULL_END
