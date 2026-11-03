#import "SentryDefines.h"
#import "SentryScope.h"
@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

// Redeclare existing SDK selectors with module-safe types; implementations remain in the SDK.
@interface SentryScope (TestAccess)
#if SWIFT_PACKAGE
- (SENTRY_SWIFT_MIGRATION_ID(SentryPropagationContext))propagationContext NS_SWIFT_NAME(test_propagationContext());
- (void)setPropagationContext:(SENTRY_SWIFT_MIGRATION_ID(SentryPropagationContext))context
    NS_SWIFT_NAME(test_setPropagationContext(_:));
#endif
- (void)applyToSession:(SENTRY_SWIFT_MIGRATION_ID(SentrySession))session
    NS_SWIFT_NAME(applyTo(session:));
@end

NS_ASSUME_NONNULL_END
