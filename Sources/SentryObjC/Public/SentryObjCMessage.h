#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Carries a log message that describes an event or error. Optionally, it can carry a format string
 * and structured parameters. This can help to group similar messages into the same issue.
 * @see https://develop.sentry.dev/sdk/event-payloads/message/
 */
@interface SentryObjCMessage : NSObject

/**
 * The fully formatted message. If missing, Sentry will try to interpolate the message. It must not
 * exceed 8192 characters. Longer messages will be truncated.
 */
@property (nonatomic, readonly, copy) NSString *formatted;

/**
 * The raw message string (uninterpolated). It must not exceed 8192 characters. Longer messages will
 * be truncated.
 */
@property (nonatomic, copy, nullable) NSString *message;

/**
 * A list of formatting parameters for the raw message.
 */
@property (nonatomic, strong, nullable) NSArray<NSString *> *params;

/**
 * Returns a @c SentryObjCMessage with setting formatted.
 * @param formatted The fully formatted message. If missing, Sentry will try to interpolate the
 * message. The backend will truncate messages longer than 8192 characters.
 */
- (instancetype)initWithFormatted:(NSString *)formatted;

@end

NS_ASSUME_NONNULL_END
