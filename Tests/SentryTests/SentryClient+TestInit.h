#import "SentryRandom.h"
#import "SentryTransport.h"
#import <Sentry/Sentry.h>

@class SentryCrashWrapper, SentryThreadInspector, SentryTransportAdapter;

NS_ASSUME_NONNULL_BEGIN

/** Expose the internal test init for testing. */
@interface
SentryClient (TestInit)

- (instancetype)initWithOptions:(SentryOptions *)options
               transportAdapter:(SentryTransportAdapter *)transportAdapter
                    fileManager:(SentryFileManager *)fileManager
                threadInspector:(SentryThreadInspector *)threadInspector
                         random:(id<SentryRandom>)random;

@end

NS_ASSUME_NONNULL_END
