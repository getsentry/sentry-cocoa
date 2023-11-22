#import "SentryDefines.h"

#import "SentryTransport.h"

@class SentryOptions, SentryFileManager;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TransportInitializer)
@interface SentryTransportFactory : SENTRY_BASE_OBJECT

+ (id<SentryTransport>)initTransport:(SentryOptions *)options
                   sentryFileManager:(SentryFileManager *)sentryFileManager;

@end

NS_ASSUME_NONNULL_END
