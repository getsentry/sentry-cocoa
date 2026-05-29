#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A 16 character hexadecimal string identifying a span within a trace.
 */
@interface SentryObjCSpanId : NSObject

/// Returns the span id as a hexadecimal string.
@property (nonatomic, readonly, copy) NSString *sentrySpanIdString;

/// A @c SentryObjCSpanId with an empty id @c "0000000000000000".
@property (nonatomic, class, readonly, strong) SentryObjCSpanId *empty;

/// Creates a @c SentryObjCSpanId with a random 16 character id.
- (instancetype)init;

/// Creates a @c SentryObjCSpanId with the first 16 characters of the given UUID.
- (instancetype)initWithUuid:(NSUUID *)uuid;

/**
 * Creates a @c SentryObjCSpanId from a 16 character string.
 * Returns an empty @c SentryObjCSpanId if the input is invalid.
 */
- (instancetype)initWithValue:(NSString *)value;

@end

NS_ASSUME_NONNULL_END
