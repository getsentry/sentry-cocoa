#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The Http status code range. Example for a range: 400 to 499, 500 to 599, 400 to 599 The range is
 * inclusive so the min and max is considered part of the range.
 *
 * Example for a single status code 400, 500
 */
NS_SWIFT_NAME(HttpStatusCodeRange)
@interface SentryHttpStatusCodeRange : NSObject
SENTRY_NO_INIT

@property (nonatomic, readonly) NSInteger min;

@property (nonatomic, readonly) NSInteger max;

- (instancetype)initWithMin:(NSInteger)min max:(NSInteger)max;

- (instancetype)initWithStatusCode:(NSInteger)statusCode;

- (BOOL)isInRange:(NSInteger)statusCode;

@end

NS_ASSUME_NONNULL_END
