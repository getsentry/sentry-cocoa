#import "SentryLog.h"
#import "SentryLogOutput.h"
#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryLog (TestInit)

/** Internal and only needed for testing. */
+ (id<SentryLogOutputProtocol>)logOutput;

/** Internal and only needed for testing. */
+ (void)setLogOutput:(nullable id<SentryLogOutputProtocol>)output;

@end

NS_ASSUME_NONNULL_END
