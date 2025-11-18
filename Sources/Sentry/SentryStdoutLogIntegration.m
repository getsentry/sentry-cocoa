#import "SentryStdOutLogIntegration.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"

@interface SentryStdOutLogIntegration ()

@property (strong, nonatomic, nullable) SentryStdOutLogIntegrationDriver *driver;

@end

@implementation SentryStdOutLogIntegration

// Only for testing
- (instancetype)initWithDispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
                               logger:(SentryLogger *)logger
{
    if (self = [super init]) {
        _driver = [[SentryStdOutLogIntegrationDriver alloc] initWithDispatchQueue:dispatchQueue
                                                                           logger:logger];
    }
    return self;
}

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    // Only install if logs are enabled
    if (!options.enableLogs) {
        return NO;
    }

    // Only install if experimental flag is enabled
    if (!options.experimental.enableStdOutCapture) {
        return NO;
    }

    // Use default instances if driver wasn't initialized (for production use)
    if (!_driver) {
        SentryLogger *logger = SentrySDK.logger;
        SentryDispatchQueueWrapper *dispatchQueue
            = SentryDependencyContainer.sharedInstance.dispatchQueueWrapper;
        _driver = [[SentryStdOutLogIntegrationDriver alloc] initWithDispatchQueue:dispatchQueue
                                                                           logger:logger];
    }

    [_driver start];

    return YES;
}

- (void)uninstall
{
    [_driver stop];
}

@end
