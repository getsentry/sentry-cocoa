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

@implementation SentrySessionReplayIntegration {
    SentrySessionReplay * sessionReplay;
}

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    if ([super installWithOptions:options] == NO) {
        return NO;
    }
    
    if (options.replaySettings.replaysSessionSampleRate == 0 && options.replaySettings.replaysOnErrorSampleRate == 0) {
        return NO;
    }
    
    sessionReplay = [[SentrySessionReplay alloc] initWithSettings:options.replaySettings];
        
    [sessionReplay start:SentryDependencyContainer.sharedInstance.application.windows.firstObject
             fullSession:[self shouldReplayFullSession:options.replaySettings.replaysSessionSampleRate]];
    
    SentryClient *client = [SentrySDK.currentHub getClient];
    [client addAttachmentProcessor:sessionReplay];
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(stop) name:UIApplicationDidEnterBackgroundNotification object:nil];
    return YES;
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
