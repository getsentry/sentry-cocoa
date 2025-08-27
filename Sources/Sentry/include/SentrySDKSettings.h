#if __has_include(<Sentry/SentryInternalSerializable.h>)
#    import <Sentry/SentryInternalSerializable.h>
#else
#    import "SentryInternalSerializable.h"
#endif

#import <Foundation/Foundation.h>

@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

/**
 * Describes the settings for the Sentry SDK
 * @see https://develop.sentry.dev/sdk/event-payloads/sdk/
 */
@interface SentrySDKSettings : NSObject <SentryInternalSerializable>

- (instancetype)initWithOptions:(SentryOptions *_Nullable)options;

- (instancetype)initWithDict:(NSDictionary *)dict;

@property (nonatomic, assign) BOOL autoInferIP;

@end

NS_ASSUME_NONNULL_END
