#import "SentryDefines.h"
@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

// Redeclare existing SDK selectors with module-safe types; implementations remain in the SDK.
// Xcode sees these selectors on the Swift class directly. Naming that class from this Clang
// module requires the Swift module, which is only imported for SwiftPM.
#if SWIFT_PACKAGE
@import SentrySwift;

@interface SentryScope (TestAccess)
- (SENTRY_SWIFT_MIGRATION_ID(SentryPropagationContext))propagationContext NS_SWIFT_NAME(test_propagationContext());
- (void)setPropagationContext:(SENTRY_SWIFT_MIGRATION_ID(SentryPropagationContext))context
    NS_SWIFT_NAME(test_setPropagationContext(_:));
- (void)applyToSession:(SENTRY_SWIFT_MIGRATION_ID(SentrySession))session
    NS_SWIFT_NAME(applyTo(session:));
@end
#endif

NS_ASSUME_NONNULL_END
