#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"
#import "SentryObjCSerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Log message describing an event or error.
 *
 * @see https://develop.sentry.dev/sdk/event-payloads/message/
 */
@interface SentryMessage : NSObject <SentrySerializable>

SENTRY_NO_INIT

- (instancetype)initWithFormatted:(NSString *)formatted;

@property (nonatomic, readonly, copy) NSString *formatted;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, strong) NSArray<NSString *> *params;

@end

NS_ASSUME_NONNULL_END
