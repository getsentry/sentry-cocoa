#import "SentryTransaction.h"

@class SentrySpanId, SentrySpan;

NS_ASSUME_NONNULL_BEGIN

/**
 * SentryTransaction SDK internal methods.
 * This should not be in the public API.
 */
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
- (SentrySpan *)startChildWithParentId:(SentrySpanId *)parentId
                             operation:(NSString *)operation
                           description:(nullable NSString *)description;

@end

NS_ASSUME_NONNULL_END
