
#import <Sentry/Sentry.h>

// Added to run integration tests, do not attempt this in your app
@interface SentryHubInternal : NSObject

@property (nonatomic, strong) NSMutableArray<NSObject *> *installedIntegrations;

@end

@interface SentrySDKInternal : NSObject

+ (SentryHubInternal *)currentHub;

@end

@interface SentryHub (DuplicatedSDKTest)

@property (nonatomic, strong) NSMutableArray<NSObject *> *installedIntegrations;

@end
