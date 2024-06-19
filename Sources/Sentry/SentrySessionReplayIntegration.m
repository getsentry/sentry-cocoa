#import "SentrySessionReplayIntegration+Private.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import "SentryClient+Private.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDisplayLinkWrapper.h"
#    import "SentryFileManager.h"
#    import "SentryGlobalEventProcessor.h"
#    import "SentryHub+Private.h"
#    import "SentryNSNotificationCenterWrapper.h"
#    import "SentryOptions.h"
#    import "SentryRandom.h"
#    import "SentrySDK+Private.h"
#    import "SentrySessionReplay.h"
#    import "SentrySwift.h"
#    import "SentrySwizzle.h"
#    import "SentryUIApplication.h"
#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *SENTRY_REPLAY_FOLDER = @"replay";

/**
 * We need to use this from the swizzled block
 * and using an instance property would hold reference
 * and leak memory.
 */
static SentryTouchTracker *_touchTracker;

@interface
SentrySessionReplayIntegration ()
- (void)newSceneActivate;
@end

@implementation SentrySessionReplayIntegration {
    BOOL _startedAsFullSession;
    SentryReplayOptions *_replayOptions;
}

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    if ([super installWithOptions:options] == NO) {
        return NO;
    }

    if (@available(iOS 16.0, tvOS 16.0, *)) {
        _replayOptions = options.experimental.sessionReplay;

        _startedAsFullSession = [self shouldReplayFullSession:_replayOptions.sessionSampleRate];

        if (!_startedAsFullSession && _replayOptions.errorSampleRate == 0) {
            return NO;
        }

        if (options.enableSwizzling) {
            _touchTracker = [[SentryTouchTracker alloc]
                initWithDateProvider:SentryDependencyContainer.sharedInstance.dateProvider
                               scale:options.experimental.sessionReplay.sizeScale];
            [self swizzleApplicationTouch];
        }

        if (SentryDependencyContainer.sharedInstance.application.windows.count > 0) {
            // If a window its already available start replay right away
            [self startWithOptions:_replayOptions fullSession:_startedAsFullSession];
        } else {
            // Wait for a scene to be available to started the replay
            [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
                addObserver:self
                   selector:@selector(newSceneActivate)
                       name:UISceneDidActivateNotification];
        }

        return YES;
    } else {
        return NO;
    }
}

- (void)newSceneActivate
{
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper removeObserver:self];
    [self startWithOptions:_replayOptions fullSession:_startedAsFullSession];
}

- (void)startWithOptions:(SentryReplayOptions *)replayOptions
             fullSession:(BOOL)shouldReplayFullSession
{
    [self startWithOptions:replayOptions
         screenshotProvider:SentryViewPhotographer.shared
        breadcrumbConverter:[[SentrySRDefaultBreadcrumbConverter alloc] init]
                fullSession:shouldReplayFullSession];
}

- (void)startWithOptions:(SentryReplayOptions *)replayOptions
      screenshotProvider:(id<SentryViewScreenshotProvider>)screenshotProvider
     breadcrumbConverter:(id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
             fullSession:(BOOL)shouldReplayFullSession
{
    if (@available(iOS 16.0, tvOS 16.0, *)) {
        NSURL *docs = [NSURL
            fileURLWithPath:[SentryDependencyContainer.sharedInstance.fileManager sentryPath]];
        docs = [docs URLByAppendingPathComponent:SENTRY_REPLAY_FOLDER];
        NSString *currentSession = [NSUUID UUID].UUIDString;
        docs = [docs URLByAppendingPathComponent:currentSession];

        if (![NSFileManager.defaultManager fileExistsAtPath:docs.path]) {
            [NSFileManager.defaultManager createDirectoryAtURL:docs
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:nil];
        }

        SentryOnDemandReplay *replayMaker =
            [[SentryOnDemandReplay alloc] initWithOutputPath:docs.path];
        replayMaker.bitRate = replayOptions.replayBitRate;
        replayMaker.cacheMaxSize
            = (NSInteger)(shouldReplayFullSession ? replayOptions.sessionSegmentDuration
                                                  : replayOptions.errorReplayDuration);

        self.sessionReplay = [[SentrySessionReplay alloc]
               initWithSettings:replayOptions
               replayFolderPath:docs
             screenshotProvider:screenshotProvider
                    replayMaker:replayMaker
            breadcrumbConverter:breadcrumbConverter
                   touchTracker:_touchTracker
                   dateProvider:SentryDependencyContainer.sharedInstance.dateProvider
                         random:SentryDependencyContainer.sharedInstance.random
             displayLinkWrapper:[[SentryDisplayLinkWrapper alloc] init]];

        [self.sessionReplay
                  start:SentryDependencyContainer.sharedInstance.application.windows.firstObject
            fullSession:[self shouldReplayFullSession:replayOptions.sessionSampleRate]];

        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(stop)
                                                   name:UIApplicationDidEnterBackgroundNotification
                                                 object:nil];

        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(resume)
                                                   name:UIApplicationWillEnterForegroundNotification
                                                 object:nil];

        [SentryGlobalEventProcessor.shared
            addEventProcessor:^SentryEvent *_Nullable(SentryEvent *_Nonnull event) {
                [self.sessionReplay captureReplayForEvent:event];
                return event;
            }];
    }
}

- (void)stop
{
    [self.sessionReplay stop];
}

- (void)resume
{
    [self.sessionReplay resume];
}

- (void)captureReplay
{
    [self.sessionReplay captureReplay];
}

- (void)configureReplayWith:(nullable id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
         screenshotProvider:(nullable id<SentryViewScreenshotProvider>)screenshotProvider
{
    if (breadcrumbConverter) {
        self.sessionReplay.breadcrumbConverter = breadcrumbConverter;
    }

    if (screenshotProvider) {
        self.sessionReplay.screenshotProvider = screenshotProvider;
    }
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableReplay;
}

- (void)uninstall
{
    _touchTracker = nil;
    [self stop];
}

- (BOOL)shouldReplayFullSession:(CGFloat)rate
{
    return [SentryDependencyContainer.sharedInstance.random nextNumber] < rate;
}

- (void)swizzleApplicationTouch
{
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"
    SEL selector = NSSelectorFromString(@"sendEvent:");
    SentrySwizzleInstanceMethod([UIApplication class], selector, SentrySWReturnType(void),
        SentrySWArguments(UIEvent * event), SentrySWReplacement({
            [_touchTracker trackTouchFromEvent:event];
            SentrySWCallOriginal(event);
        }),
        SentrySwizzleModeOncePerClass, (void *)selector);
#    pragma clang diagnostic pop
}

#    if TEST || TESTCI
- (SentryTouchTracker *)getTouchTracker
{
    return _touchTracker;
}
#    endif

@end
NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
