#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * An HTTP status code range.
 *
 * @see SentryOptions
 */
@interface SentryHttpStatusCodeRange : NSObject

SENTRY_NO_INIT

@property (nonatomic, readonly) NSInteger min;
@property (nonatomic, readonly) NSInteger max;

/** Creates a range with min and max (inclusive). */
- (instancetype)initWithMin:(NSInteger)min max:(NSInteger)max;

/** Creates a range for a single status code. */
- (instancetype)initWithStatusCode:(NSInteger)statusCode;

@end

NS_ASSUME_NONNULL_END
