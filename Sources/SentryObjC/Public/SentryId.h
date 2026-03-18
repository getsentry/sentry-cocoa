#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A 32-character hexadecimal identifier used for events, traces, and spans.
 *
 * @see SentryEvent
 * @see SentrySpanContext
 */
@interface SentryId : NSObject

/** A SentryId with an empty UUID "00000000000000000000000000000000". */
@property (nonatomic, class, readonly, strong) SentryId *empty;

/** Returns a 32 lowercase character hexadecimal string, e.g. "12c2d058d58442709aa2eca08bf20986". */
@property (nonatomic, readonly, copy) NSString *sentryIdString;

/** Creates a SentryId with a random UUID. */
- (instancetype)init;

/** Creates a SentryId with the given UUID. */
- (instancetype)initWithUuid:(NSUUID *)uuid;

/**
 * Creates a SentryId from a 32- or 36-character hexadecimal string.
 *
 * @param uuidString A string like "12c2d058d58442709aa2eca08bf20986" or
 *        "12c2d058-d584-4270-9aa2-eca08bf20986".
 * @return SentryId.empty for invalid strings.
 */
- (instancetype)initWithUUIDString:(NSString *)uuidString;

- (BOOL)isEqual:(nullable id)object;

@end

NS_ASSUME_NONNULL_END
