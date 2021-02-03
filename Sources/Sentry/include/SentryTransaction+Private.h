#import "SentryTransaction.h"

@class SentrySpanId, SentrySpan;

NS_ASSUME_NONNULL_BEGIN

@interface SentryTransaction (Private)

/**
 * Starts a child span.
 *
 * @param parentId The child span parent id.
 * @param operation The child span operation.
 * @param description The child span description.
 *
 * @return SentrySpan
 */
- (SentrySpan *) startChildWithParentId:(SentrySpanId *)parentId
                              operation:(NSString *)operation
                         andDescription:(nullable NSString *)description;

@end

NS_ASSUME_NONNULL_END
