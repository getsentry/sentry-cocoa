#import "SentryDefines.h"
#import "SentryTracer+Private.h"
@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

// Redeclare existing SDK selectors with module-safe types; implementations remain in the SDK.
@interface SentryTracer (TestAccess)
- (NSDictionary *)measurements NS_SWIFT_NAME(test_measurements());
@end

NS_ASSUME_NONNULL_END
