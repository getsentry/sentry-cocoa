#import "SentryTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryTransaction (Private)

/**
 * A list of child spans.
 */
@property (nonatomic) NSMutableArray<SentrySpan *> * spans;

@end

NS_ASSUME_NONNULL_END
