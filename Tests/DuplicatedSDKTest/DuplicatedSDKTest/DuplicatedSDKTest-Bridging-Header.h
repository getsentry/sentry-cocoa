
#import <Sentry/Sentry.h>

// Added to run integration tests, do not attempt this in your app
@interface SentrySDKInternal : NSObject

+ (SentryHub *)currentHub;

@end

@interface SentryHub (DuplicatedSDKTest)

@property (nonatomic, strong) NSMutableArray<id<SentryIntegrationProtocol>> *installedIntegrations;

@end
