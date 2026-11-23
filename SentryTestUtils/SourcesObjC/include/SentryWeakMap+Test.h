#import "SentryWeakMap.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryWeakMap (Test)

// Expose the shared cleanup path so regression tests can count bounded and full-prune work.
- (void)pruneNextEntries:(NSUInteger)limit;

@end

NS_ASSUME_NONNULL_END
