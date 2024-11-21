
#import <Sentry/Sentry.h>

@interface SentrySDK (DuplicatedSDKTest)

+ (SentryHub *)currentHub;

@end

@interface SentryHub (DuplicatedSDKTest)

@property (nonatomic, strong) NSMutableArray<id<SentryIntegrationProtocol>> *installedIntegrations;

@end
