#import "SentrySessionReplayIntegration+Private.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import "SentryClient+Private.h"
#    import "SentryCrashWrapper.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryDisplayLinkWrapper.h"
#    import "SentryEvent+Private.h"
#    import "SentryFileManager.h"
#    import "SentryGlobalEventProcessor.h"
#    import "SentryHub+Private.h"
#    import "SentryLog.h"
#    import "SentryNSNotificationCenterWrapper.h"
#    import "SentryOptions.h"
#    import "SentryRandom.h"
#    import "SentryRateLimits.h"
#    import "SentryReachability.h"
#    import "SentrySDK+Private.h"
#    import "SentryScope+Private.h"
#    import "SentrySerialization.h"
#    import "SentrySessionReplaySyncC.h"
#    import "SentrySwift.h"
#    import "SentrySwizzle.h"
#    import "SentryUIApplication.h"
#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *SENTRY_REPLAY_FOLDER = @"replay";
static NSString *SENTRY_CURRENT_REPLAY = @"replay.current";
static NSString *SENTRY_LAST_REPLAY = @"replay.last";

/**
 * We need to use this from the swizzled block
 * and using an instance property would hold reference
 * and leak memory.
 */
static SentryTouchTracker *_touchTracker;

@interface SentrySessionReplayIntegration () <SentryReachabilityObserver>
- (void)newSceneActivate;
@end

@implementation SentrySessionReplayIntegration {
    BOOL _startedAsFullSession;
    SentryReplayOptions *_replayOptions;
    SentryNSNotificationCenterWrapper *_notificationCenter;
    SentryOnDemandReplay *_resumeReplayMaker;
    id<SentryRateLimits> _rateLimits;
    id<SentryViewScreenshotProvider> _currentScreenshotProvider;
    id<SentryReplayBreadcrumbConverter> _currentBreadcrumbConverter;
    SentryMaskingPreviewView *_previewView;
    // We need to use this variable to identify whether rate limiting was ever activated for session
    // replay in this session, instead of always looking for the rate status in `SentryRateLimits`
    // This is the easiest way to ensure segment 0 will always reach the server, because session
    // replay absolutely needs segment 0 to make replay work.
    BOOL _rateLimited;
}

- (instancetype)init
{
    self = [super init];
    return self;
}

- (instancetype)initForManualUse:(nonnull SentryOptions *)options
{
    if (self = [super init]) {
        [self setupWith:options.sessionReplay enableTouchTracker:options.enableSwizzling];
        [self startWithOptions:options.sessionReplay fullSession:YES];
    }
    return self;
}

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    if ([super installWithOptions:options] == NO) {
        return NO;
    }

    [self setupWith:options.sessionReplay enableTouchTracker:options.enableSwizzling];
    return YES;
}

- (void)setupWith:(SentryReplayOptions *)replayOptions enableTouchTracker:(BOOL)touchTracker
{
    _replayOptions = replayOptions;
    _viewPhotographer = [[SentryViewPhotographer alloc] initWithRedactOptions:replayOptions];
    _rateLimits = SentryDependencyContainer.sharedInstance.rateLimits;

    if (touchTracker) {
        _touchTracker = [[SentryTouchTracker alloc]
            initWithDateProvider:SentryDependencyContainer.sharedInstance.dateProvider
                           scale:replayOptions.sizeScale];
        [self swizzleApplicationTouch];
    }

    _notificationCenter = SentryDependencyContainer.sharedInstance.notificationCenterWrapper;

    [self moveCurrentReplay];
    [self cleanUp];

    [SentrySDK.currentHub registerSessionListener:self];
    [SentryGlobalEventProcessor.shared
        addEventProcessor:^SentryEvent *_Nullable(SentryEvent *_Nonnull event) {
            if (event.isCrashEvent) {
                [self resumePreviousSessionReplay:event];
            } else {
                [self.sessionReplay captureReplayForEvent:event];
            }
            return event;
        }];

    [SentryDependencyContainer.sharedInstance.reachability addObserver:self];
}

- (nullable NSDictionary<NSString *, id> *)lastReplayInfo
{
    NSURL *dir = [self replayDirectory];
    NSURL *lastReplayUrl = [dir URLByAppendingPathComponent:SENTRY_LAST_REPLAY];
    NSData *lastReplay = [NSData dataWithContentsOfURL:lastReplayUrl];

    if (lastReplay == nil) {
        return nil;
    }

    return [SentrySerialization deserializeDictionaryFromJsonData:lastReplay];
}

/**
 * Send the cached frames from a previous session that eventually crashed.
 * This function is called when processing an event created by SentryCrashIntegration,
 * which runs in the background. That's why we don't need to dispatch the generation of the
 * replay to the background in this function.
 */
- (void)resumePreviousSessionReplay:(SentryEvent *)event
{
    NSURL *dir = [self replayDirectory];
    NSDictionary<NSString *, id> *jsonObject = [self lastReplayInfo];

    if (jsonObject == nil) {
        return;
    }

    SentryId *replayId = jsonObject[@"replayId"]
        ? [[SentryId alloc] initWithUUIDString:jsonObject[@"replayId"]]
        : [[SentryId alloc] init];
    NSURL *lastReplayURL = [dir URLByAppendingPathComponent:jsonObject[@"path"]];

    SentryCrashReplay crashInfo = { 0 };
    bool hasCrashInfo = sentrySessionReplaySync_readInfo(&crashInfo,
        [[lastReplayURL URLByAppendingPathComponent:@"crashInfo"].path
            cStringUsingEncoding:NSUTF8StringEncoding]);

    SentryReplayType type = hasCrashInfo ? SentryReplayTypeSession : SentryReplayTypeBuffer;
    NSTimeInterval duration
        = hasCrashInfo ? _replayOptions.sessionSegmentDuration : _replayOptions.errorReplayDuration;
    int segmentId = hasCrashInfo ? crashInfo.segmentId + 1 : 0;

    if (type == SentryReplayTypeBuffer) {
        float errorSampleRate = [jsonObject[@"errorSampleRate"] floatValue];
        if ([SentryDependencyContainer.sharedInstance.random nextNumber] >= errorSampleRate) {
            return;
        }
    }

    SentryOnDemandReplay *resumeReplayMaker =
        [[SentryOnDemandReplay alloc] initWithContentFrom:lastReplayURL.path];
    resumeReplayMaker.bitRate = _replayOptions.replayBitRate;
    resumeReplayMaker.videoScale = _replayOptions.sizeScale;

    NSDate *beginning = hasCrashInfo
        ? [NSDate dateWithTimeIntervalSinceReferenceDate:crashInfo.lastSegmentEnd]
        : [resumeReplayMaker oldestFrameDate];

    if (beginning == nil) {
        return; // no frames to send
    }

    SentryReplayType _type = type;
    int _segmentId = segmentId;

    NSError *error;
    NSArray<SentryVideoInfo *> *videos =
        [resumeReplayMaker createVideoWithBeginning:beginning
                                                end:[beginning dateByAddingTimeInterval:duration]
                                              error:&error];
    if (videos == nil) {
        SENTRY_LOG_ERROR(@"Could not create replay video: %@", error);
        return;
    }
    for (SentryVideoInfo *video in videos) {
        [self captureVideo:video replayId:replayId segmentId:_segmentId++ type:_type];
        // type buffer is only for the first segment
        _type = SentryReplayTypeSession;
    }

    NSMutableDictionary *eventContext = event.context.mutableCopy;
    eventContext[@"replay"] =
        [NSDictionary dictionaryWithObjectsAndKeys:replayId.sentryIdString, @"replay_id", nil];
    event.context = eventContext;

    if ([NSFileManager.defaultManager removeItemAtURL:lastReplayURL error:&error] == NO) {
        SENTRY_LOG_ERROR(@"Can`t delete '%@': %@", SENTRY_LAST_REPLAY, error);
    }
}

- (void)captureVideo:(SentryVideoInfo *)video
            replayId:(SentryId *)replayId
           segmentId:(int)segment
                type:(SentryReplayType)type
{
    SentryReplayEvent *replayEvent = [[SentryReplayEvent alloc] initWithEventId:replayId
                                                           replayStartTimestamp:video.start
                                                                     replayType:type
                                                                      segmentId:segment];
    replayEvent.timestamp = video.end;
    SentryReplayRecording *recording = [[SentryReplayRecording alloc] initWithSegmentId:segment
                                                                                  video:video
                                                                            extraEvents:@[]];

    [SentrySDK.currentHub captureReplayEvent:replayEvent
                             replayRecording:recording
                                       video:video.path];

    NSError *error = nil;
    if (![[NSFileManager defaultManager] removeItemAtURL:video.path error:&error]) {
        SENTRY_LOG_DEBUG(
            @"Could not delete replay segment from disk: %@", error.localizedDescription);
    }
}

- (void)startSession
{
    [self.sessionReplay pause];

    _startedAsFullSession = [self shouldReplayFullSession:_replayOptions.sessionSampleRate];

    if (!_startedAsFullSession && _replayOptions.onErrorSampleRate == 0) {
        return;
    }

    [self runReplayForAvailableWindow];
}

- (void)runReplayForAvailableWindow
{
    if (SentryDependencyContainer.sharedInstance.application.windows.count > 0) {
        // If a window its already available start replay right away
        [self startWithOptions:_replayOptions fullSession:_startedAsFullSession];
    } else if (@available(iOS 13.0, tvOS 13.0, *)) {
        // Wait for a scene to be available to started the replay
        [_notificationCenter addObserver:self
                                selector:@selector(newSceneActivate)
                                    name:UISceneDidActivateNotification];
    }
}

- (void)newSceneActivate
{
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
            removeObserver:self
                      name:UISceneDidActivateNotification];
        [self startWithOptions:_replayOptions fullSession:_startedAsFullSession];
    }
}

- (void)startWithOptions:(SentryReplayOptions *)replayOptions
             fullSession:(BOOL)shouldReplayFullSession
{
    [self startWithOptions:replayOptions
         screenshotProvider:_currentScreenshotProvider ?: _viewPhotographer
        breadcrumbConverter:_currentBreadcrumbConverter
            ?: [[SentrySRDefaultBreadcrumbConverter alloc] init]
                fullSession:shouldReplayFullSession];
}

- (void)startWithOptions:(SentryReplayOptions *)replayOptions
      screenshotProvider:(id<SentryViewScreenshotProvider>)screenshotProvider
     breadcrumbConverter:(id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
             fullSession:(BOOL)shouldReplayFullSession
{
    NSURL *docs = [self replayDirectory];
    NSString *currentSession = [NSUUID UUID].UUIDString;
    docs = [docs URLByAppendingPathComponent:currentSession];

    if (![NSFileManager.defaultManager fileExistsAtPath:docs.path]) {
        [NSFileManager.defaultManager createDirectoryAtURL:docs
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:nil];
    }

    SentryOnDemandReplay *replayMaker = [[SentryOnDemandReplay alloc] initWithOutputPath:docs.path];
    replayMaker.bitRate = replayOptions.replayBitRate;
    replayMaker.videoScale = replayOptions.sizeScale;
    replayMaker.cacheMaxSize
        = (NSInteger)(shouldReplayFullSession ? replayOptions.sessionSegmentDuration + 1
                                              : replayOptions.errorReplayDuration + 1);

    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_LOW, 0);
    SentryDispatchQueueWrapper *dispatchQueue =
        [[SentryDispatchQueueWrapper alloc] initWithName:"io.sentry.session-replay"
                                              attributes:attributes];

    self.sessionReplay = [[SentrySessionReplay alloc]
        initWithReplayOptions:replayOptions
             replayFolderPath:docs
           screenshotProvider:screenshotProvider
                  replayMaker:replayMaker
          breadcrumbConverter:breadcrumbConverter
                 touchTracker:_touchTracker
                 dateProvider:SentryDependencyContainer.sharedInstance.dateProvider
                     delegate:self
                dispatchQueue:dispatchQueue
           displayLinkWrapper:[[SentryDisplayLinkWrapper alloc] init]];

    [self.sessionReplay
        startWithRootView:SentryDependencyContainer.sharedInstance.application.windows.firstObject
              fullSession:shouldReplayFullSession];

    [_notificationCenter addObserver:self
                            selector:@selector(pause)
                                name:UIApplicationDidEnterBackgroundNotification
                              object:nil];

    [_notificationCenter addObserver:self
                            selector:@selector(resume)
                                name:UIApplicationDidBecomeActiveNotification
                              object:nil];

    [self saveCurrentSessionInfo:self.sessionReplay.sessionReplayId
                            path:docs.path
                         options:replayOptions];
}

- (NSURL *)replayDirectory
{
    NSURL *dir =
        [NSURL fileURLWithPath:[SentryDependencyContainer.sharedInstance.fileManager sentryPath]];
    return [dir URLByAppendingPathComponent:SENTRY_REPLAY_FOLDER];
}

- (void)saveCurrentSessionInfo:(SentryId *)sessionId
                          path:(NSString *)path
                       options:(SentryReplayOptions *)options
{
    NSDictionary *info =
        [[NSDictionary alloc] initWithObjectsAndKeys:sessionId.sentryIdString, @"replayId",
            path.lastPathComponent, @"path", @(options.onErrorSampleRate), @"errorSampleRate", nil];

    NSData *data = [SentrySerialization dataWithJSONObject:info];

    NSString *infoPath = [[path stringByDeletingLastPathComponent]
        stringByAppendingPathComponent:SENTRY_CURRENT_REPLAY];
    if ([NSFileManager.defaultManager fileExistsAtPath:infoPath]) {
        [NSFileManager.defaultManager removeItemAtPath:infoPath error:nil];
    }
    [data writeToFile:infoPath atomically:YES];

    sentrySessionReplaySync_start([[path stringByAppendingPathComponent:@"crashInfo"]
        cStringUsingEncoding:NSUTF8StringEncoding]);
}

- (void)moveCurrentReplay
{
    NSURL *path = [self replayDirectory];
    NSURL *current = [path URLByAppendingPathComponent:SENTRY_CURRENT_REPLAY];
    NSURL *last = [path URLByAppendingPathComponent:SENTRY_LAST_REPLAY];

    NSError *error;
    if ([NSFileManager.defaultManager fileExistsAtPath:last.path]) {
        if ([NSFileManager.defaultManager removeItemAtURL:last error:&error] == NO) {
            SENTRY_LOG_ERROR(@"Could not delete 'lastreplay' file: %@", error);
            return;
        }
    }

    if ([NSFileManager.defaultManager moveItemAtURL:current toURL:last error:nil] == NO) {
        SENTRY_LOG_ERROR(@"Could not move 'currentreplay' to 'lastreplay': %@", error);
    }
}

- (void)cleanUp
{
    NSURL *replayDir = [self replayDirectory];
    NSDictionary<NSString *, id> *lastReplayInfo = [self lastReplayInfo];
    NSString *lastReplayFolder = lastReplayInfo[@"path"];

    SentryFileManager *fileManager = SentryDependencyContainer.sharedInstance.fileManager;
    // Mapping replay folder here and not in dispatched queue to prevent a race condition between
    // listing files and creating a new replay session.
    NSArray *replayFiles = [fileManager allFilesInFolder:replayDir.path];
    if (replayFiles.count == 0) {
        return;
    }

    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncWithBlock:^{
        for (NSString *file in replayFiles) {
            // Skip the last replay folder.
            if ([file isEqualToString:lastReplayFolder]) {
                continue;
            }

            NSString *filePath = [replayDir.path stringByAppendingPathComponent:file];

            // Check if the file is a directory before deleting it.
            if ([fileManager isDirectory:filePath]) {
                [fileManager removeFileAtPath:filePath];
            }
        }
    }];
}

- (void)pause
{
    [self.sessionReplay pause];
}

- (void)resume
{
    [self.sessionReplay resume];
}

- (void)start
{
    if (_rateLimited) {
        SENTRY_LOG_WARN(
            @"This session was rate limited. Not starting session replay until next app session");
        return;
    }

    if (self.sessionReplay != nil) {
        if (self.sessionReplay.isFullSession == NO) {
            [self.sessionReplay captureReplay];
        }
        return;
    }

    _startedAsFullSession = YES;
    [self runReplayForAvailableWindow];
}

- (void)stop
{
    [self.sessionReplay pause];
    self.sessionReplay = nil;
}

- (void)sentrySessionEnded:(SentrySession *)session
{
    [self pause];
    [_notificationCenter removeObserver:self
                                   name:UIApplicationDidEnterBackgroundNotification
                                 object:nil];
    [_notificationCenter removeObserver:self
                                   name:UIApplicationWillEnterForegroundNotification
                                 object:nil];
    _sessionReplay = nil;
}

- (void)sentrySessionStarted:(SentrySession *)session
{
    _rateLimited = NO;
    [self startSession];
}

- (BOOL)captureReplay
{
    return [self.sessionReplay captureReplay];
}

- (void)configureReplayWith:(nullable id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
         screenshotProvider:(nullable id<SentryViewScreenshotProvider>)screenshotProvider
{
    if (breadcrumbConverter) {
        _currentBreadcrumbConverter = breadcrumbConverter;
        self.sessionReplay.breadcrumbConverter = breadcrumbConverter;
    }

    if (screenshotProvider) {
        _currentScreenshotProvider = screenshotProvider;
        self.sessionReplay.screenshotProvider = screenshotProvider;
    }
}

- (void)setReplayTags:(NSDictionary<NSString *, id> *)tags
{
    self.sessionReplay.replayTags = [tags copy];
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableReplay;
}

- (void)uninstall
{
    [SentrySDK.currentHub unregisterSessionListener:self];
    _touchTracker = nil;
    [self pause];
}

- (void)dealloc
{
    [self uninstall];
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

#    if SENTRY_TEST || SENTRY_TEST_CI
- (SentryTouchTracker *)getTouchTracker
{
    return _touchTracker;
}
#    endif

+ (id<SentryRRWebEvent>)createBreadcrumbwithTimestamp:(NSDate *)timestamp
                                             category:(NSString *)category
                                              message:(nullable NSString *)message
                                                level:(enum SentryLevel)level
                                                 data:(nullable NSDictionary<NSString *, id> *)data
{
    return [[SentryRRWebBreadcrumbEvent alloc] initWithTimestamp:timestamp
                                                        category:category
                                                         message:message
                                                           level:level
                                                            data:data];
}

+ (id<SentryRRWebEvent>)createNetworkBreadcrumbWithTimestamp:(NSDate *)timestamp
                                                endTimestamp:(NSDate *)endTimestamp
                                                   operation:(NSString *)operation
                                                 description:(NSString *)description
                                                        data:(NSDictionary<NSString *, id> *)data
{
    return [[SentryRRWebSpanEvent alloc] initWithTimestamp:timestamp
                                              endTimestamp:endTimestamp
                                                 operation:operation
                                               description:description
                                                      data:data];
}

+ (id<SentryReplayBreadcrumbConverter>)createDefaultBreadcrumbConverter
{
    return [[SentrySRDefaultBreadcrumbConverter alloc] init];
}

#    pragma mark - SessionReplayDelegate

- (BOOL)sessionReplayShouldCaptureReplayForError
{
    return SentryDependencyContainer.sharedInstance.random.nextNumber
        <= _replayOptions.onErrorSampleRate;
}

- (void)sessionReplayNewSegmentWithReplayEvent:(SentryReplayEvent *)replayEvent
                               replayRecording:(SentryReplayRecording *)replayRecording
                                      videoUrl:(NSURL *)videoUrl
{
    if ([_rateLimits isRateLimitActive:kSentryDataCategoryReplay] ||
        [_rateLimits isRateLimitActive:kSentryDataCategoryAll]) {
        SENTRY_LOG_DEBUG(
            @"Rate limiting is active for replays. Stopping session replay until next session.");
        _rateLimited = YES;
        [self stop];
        return;
    }

    [SentrySDK.currentHub captureReplayEvent:replayEvent
                             replayRecording:replayRecording
                                       video:videoUrl];

    sentrySessionReplaySync_updateInfo(
        (unsigned int)replayEvent.segmentId, replayEvent.timestamp.timeIntervalSinceReferenceDate);
}

- (void)sessionReplayStartedWithReplayId:(SentryId *)replayId
{
    [SentrySDK.currentHub configureScope:^(
        SentryScope *_Nonnull scope) { scope.replayId = [replayId sentryIdString]; }];
}

- (NSArray<SentryBreadcrumb *> *)breadcrumbsForSessionReplay
{
    __block NSArray<SentryBreadcrumb *> *result;
    [SentrySDK.currentHub
        configureScope:^(SentryScope *_Nonnull scope) { result = scope.breadcrumbs; }];
    return result;
}

- (nullable NSString *)currentScreenNameForSessionReplay
{
    return SentrySDK.currentHub.scope.currentScreen
        ?: [SentryDependencyContainer.sharedInstance.application relevantViewControllersNames]
               .firstObject;
}

- (void)showMaskPreview:(CGFloat)opacity
{
    if ([SentryDependencyContainer.sharedInstance.crashWrapper isBeingTraced] == NO) {
        return;
    }

    UIWindow *window = SentryDependencyContainer.sharedInstance.application.windows.firstObject;
    if (window == nil) {
        SENTRY_LOG_WARN(@"There is no UIWindow available to display preview");
        return;
    }

    if (_previewView == nil) {
        _previewView = [[SentryMaskingPreviewView alloc] initWithRedactOptions:_replayOptions];
    }

    _previewView.opacity = opacity;
    [_previewView setFrame:window.bounds];
    [window addSubview:_previewView];
}

- (void)hideMaskPreview
{
    [_previewView removeFromSuperview];
    _previewView = nil;
}

#    pragma mark - SentryReachabilityObserver

- (void)connectivityChanged:(BOOL)connected typeDescription:(nonnull NSString *)typeDescription
{

    if (connected) {
        [_sessionReplay resume];
    } else {
        [_sessionReplay pauseSessionMode];
    }
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
