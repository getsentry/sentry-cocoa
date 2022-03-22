#import "SentryRandom.h"
#import "SentryTransport.h"
#import <Sentry/Sentry.h>

@class SentryCrashWrapper, SentryThreadInspector;

NS_ASSUME_NONNULL_BEGIN

/** Expose the internal test init for testing. */
@interface
SentryClient (TestInit)

- (instancetype)initWithOptions:(SentryOptions *)options
                      transport:(id<SentryTransport>)transport
                    fileManager:(SentryFileManager *)fileManager
                threadInspector:(SentryThreadInspector *)threadInspector
                         random:(id<SentryRandom>)random;

@end

NS_ASSUME_NONNULL_END
