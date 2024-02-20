#import "SentrySessionReplayIntegration.h"
#import "SentrySessionReplay.h"
#import "SentryDependencyContainer.h"
#import "SentryUIApplication.h"
#import "SentrySDK+Private.h"
#import "SentryClient+Private.h"
#import "SentryHub+Private.h"
#import "SentrySDK+Private.h"
#import "SentryReplaySettings.h"
#import "SentryRandom.h"
#import "SentryOptions.h"


@implementation SentrySessionReplayIntegration {
    SentrySessionReplay * sessionReplay;
}

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    if ([super installWithOptions:options] == NO) {
        return NO;
    }
    
    if (@available(iOS 16.0, *)) {
        if (options.sessionReplaySettings.replaysSessionSampleRate == 0 && options.sessionReplaySettings.replaysOnErrorSampleRate == 0) {
            return NO;
        }
        
        sessionReplay = [[SentrySessionReplay alloc] initWithSettings:options.sessionReplaySettings];
        
        [sessionReplay start:SentryDependencyContainer.sharedInstance.application.windows.firstObject
                 fullSession:[self shouldReplayFullSession:options.sessionReplaySettings.replaysSessionSampleRate]];
        
        SentryClient *client = [SentrySDK.currentHub getClient];
        [client addAttachmentProcessor:sessionReplay];
        
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(stop) name:UIApplicationDidEnterBackgroundNotification object:nil];
        return YES;
    } else {
        return NO;
    }
}

-(void)stop {
    [sessionReplay stop];
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableReplay;
}

- (void)uninstall
{
    
}

- (BOOL)shouldReplayFullSession:(CGFloat)rate {
    return [SentryDependencyContainer.sharedInstance.random nextNumber] < rate;
}

@end
