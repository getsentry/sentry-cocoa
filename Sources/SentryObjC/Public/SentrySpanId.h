#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A 16-character identifier for a span.
 *
 * @see SentrySpanContext
 * @see SentrySpan
 */
@interface SentrySpanId : NSObject <NSCopying>

/** Creates a SentrySpanId with a random 16 character Id. */
- (instancetype)init;

/** Creates a SentrySpanId with the first 16 characters of the given UUID. */
- (instancetype)initWithUUID:(NSUUID *)uuid;

/**
 * Creates a SentrySpanId from a 16 character string.
 *
 * @param value A 16-character string.
 * @return Empty SentrySpanId if the input is invalid.
 */
- (instancetype)initWithValue:(NSString *)value;

/** Returns the span Id value. */
@property (readonly, copy) NSString *sentrySpanIdString;

/** A SentrySpanId with an empty Id "0000000000000000". */
@property (class, nonatomic, readonly, strong) SentrySpanId *empty;

@end

NS_ASSUME_NONNULL_END
