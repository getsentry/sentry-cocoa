#import "SentryIntegrationProvider.h"
#import "SentryTransport.h"
#import <Sentry/Sentry.h>

@class SentryCrashAdapter;

NS_ASSUME_NONNULL_BEGIN

/** Expose the internal test init for testing. */
@interface
SentryClient (TestInit)

- (instancetype)initWithOptions:(SentryOptions *)options
                   andTransport:(id<SentryTransport>)transport
                 andFileManager:(SentryFileManager *)fileManager
         andIntegrationProvider:(SentryIntegrationProvider *)integrationProvider;

@end

NS_ASSUME_NONNULL_END
