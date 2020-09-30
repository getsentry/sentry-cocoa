#import "SentrySerializable.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Carries a log message that describes an event or error. Optionally, it can carry a format string
 * and structured parameters. This can help to group similar messages into the same issue.
 *
 * For more info checkout: https://develop.sentry.dev/sdk/event-payloads/message/
 */
@interface SentryMessage : NSObject <SentrySerializable>

- (instancetype)init;

/**
 * Creates a new message containing the given formatted.
 */
+ (instancetype)messageWithFormatted:(NSString *_Nullable)formatted NS_SWIFT_NAME(init(formatted:));

/**
 * The fully formatted message. If missing, Sentry will try to interpolate the message. It must not
 * exceed 8192 characters. Longer messages will be truncated.
 */
@property (nonatomic, copy) NSString *_Nullable formatted;

/**
 * The raw message string (uninterpolated). It must not exceed 8192 characters. Longer messages will
 * be truncated.
 */
@property (nonatomic, copy) NSString *_Nullable message;

/**
 * A list of formatting parameters for the raw message.
 */
@property (nonatomic, strong) NSArray<NSString *> *_Nullable params;

@end

NS_ASSUME_NONNULL_END
