#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * An HTTP status code range.
 */
@interface SentryObjCHttpStatusCodeRange : NSObject

/// The minimum HTTP status code in the range (inclusive).
@property (nonatomic, readonly) NSInteger min;

/// The maximum HTTP status code in the range (inclusive).
@property (nonatomic, readonly) NSInteger max;

/**
 * The HTTP status code min and max.
 * @discussion The range is inclusive so the min and max is considered part of the range.
 * @example For a range: 400 to 499; 500 to 599; 400 to 599.
 */
- (instancetype)initWithMin:(NSInteger)min max:(NSInteger)max;

/**
 * The HTTP status code.
 * @example For a single status code: 400; 500.
 */
- (instancetype)initWithStatusCode:(NSInteger)statusCode;

@end

NS_ASSUME_NONNULL_END
