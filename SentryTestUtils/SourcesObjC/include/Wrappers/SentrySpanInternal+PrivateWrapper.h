#import "SentryDefines.h"
#import "SentrySpanInternal.h"
@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

// Redeclare existing SDK selectors with module-safe types; implementations remain in the SDK.
// Xcode already imports the typed initializer; redeclaring it there duplicates inherited
// initializers.
#if SENTRY_HAS_UIKIT && SWIFT_PACKAGE
@interface SentrySpanInternal (TestAccess)
- (instancetype)initWithContext:(SentrySpanContext *)context
                  framesTracker:
                      (nullable SENTRY_SWIFT_MIGRATION_ID(SentryFramesTracker))framesTracker
    NS_SWIFT_NAME(init(testContext:testFramesTracker:));
@end
#endif

NS_ASSUME_NONNULL_END
