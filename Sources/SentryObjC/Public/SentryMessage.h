#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Log message describing an event or error.
 *
 * Contains a formatted message string that is displayed in Sentry, along with
 * an optional unformatted message template and parameters for structured logging.
 *
 * @see https://develop.sentry.dev/sdk/event-payloads/message/
 */
@interface SentryMessage : NSObject <SentrySerializable>

SENTRY_NO_INIT

/**
 * Creates a message with a formatted string.
 *
 * @param formatted The formatted message string to display.
 * @return A new message instance.
 */
- (instancetype)initWithFormatted:(NSString *)formatted;

/**
 * The fully formatted message string.
 *
 * This is what appears in the Sentry UI.
 */
@property (nonatomic, readonly, copy) NSString *formatted;

/**
 * The unformatted message template.
 *
 * Used for grouping similar messages with different parameter values.
 * Example: "User {user} performed action {action}".
 */
@property (nonatomic, copy) NSString *message;

/**
 * Parameters to substitute into the message template.
 *
 * Corresponds to placeholders in the @c message template.
 */
@property (nonatomic, strong) NSArray<NSString *> *params;

@end

NS_ASSUME_NONNULL_END
