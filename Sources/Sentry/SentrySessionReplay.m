#import "SentrySessionReplay.h"
#import "SentryAttachment+Private.h"
#import "SentryDependencyContainer.h"
#import "SentryFileManager.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentryReplayEvent.h"
#import "SentryReplayRecording.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"

#if SENTRY_HAS_UIKIT

static NSString *SENTRY_REPLAY_FOLDER = @"replay";

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySessionReplay {
    UIView *_rootView;
    BOOL _processingScreenshot;
    CADisplayLink *_displayLink;
    NSDate *_lastScreenShot;
    NSDate *_videoSegmentStart;
    NSURL *_urlToCache;
    NSDate *_sessionStart;
    SentryReplayOptions *_replayOptions;
    SentryOnDemandReplay *_replayMaker;
    SentryId *sessionReplayId;
    NSMutableArray<UIImage *> *imageCollection;
    int _currentSegmentId;
    BOOL _isFullSession;
}

- (instancetype)initWithSettings:(SentryReplayOptions *)replayOptions
{
    if (self = [super init]) {
        _replayOptions = replayOptions;
    }
    return self;
}

- (SentryCurrentDateProvider *)dateProvider
{
    return SentryDependencyContainer.sharedInstance.dateProvider;
}

- (void)start:(UIView *)rootView fullSession:(BOOL)full
{
    if (rootView == nil) {
        SENTRY_LOG_DEBUG(@"rootView cannot be nil. Session replay will not be recorded.");
        return;
    }

    @synchronized(self) {
        if (_displayLink == nil) {
            _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(newFrame:)];
            [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        } else {
            // Session display is already running.
            return;
        }

        _rootView = rootView;
        _lastScreenShot = [[NSDate alloc] init];
        _videoSegmentStart = nil;
        _sessionStart = _lastScreenShot;
        _currentSegmentId = 0;

        NSURL *docs = [NSURL
            fileURLWithPath:[SentryDependencyContainer.sharedInstance.fileManager sentryPath]];
        docs = [docs URLByAppendingPathComponent:SENTRY_REPLAY_FOLDER];

        NSString *currentSession = [NSUUID UUID].UUIDString;
        _urlToCache = [docs URLByAppendingPathComponent:currentSession];

        if (![NSFileManager.defaultManager fileExistsAtPath:_urlToCache.path]) {
            [NSFileManager.defaultManager createDirectoryAtURL:_urlToCache
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:nil];
        }

        _replayMaker = [[SentryOnDemandReplay alloc] initWithOutputPath:_urlToCache.path];
        _replayMaker.bitRate = _replayOptions.replayBitRate;
        _replayMaker.cacheMaxSize = (NSInteger)(full ? _replayOptions.sessionSegmentDuration
                                                     : _replayOptions.errorReplayDuration);
        imageCollection = [NSMutableArray array];

        NSLog(@"Recording session to %@", _urlToCache);

        _isFullSession = full;
        if (full) {
            sessionReplayId = [[SentryId alloc] init];
        }
    }
}

- (void)stop
{
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)replayForEvent:(SentryEvent *)event;
{
    if (_isFullSession) {
        return;
    }

    if (event.error == nil && (event.exceptions == nil || event.exceptions.count == 0)) {
        return;
    }

    if (_isFullSession) {
        [self updateEvent:event withReplayId:sessionReplayId];
        return;
    }

    NSURL *finalPath = [_urlToCache URLByAppendingPathComponent:@"replay.mp4"];
    NSDate *replayStart =
        [[self dateProvider].date dateByAddingTimeInterval:-_replayOptions.errorReplayDuration];

    [self createAndCapture:finalPath
                  duration:_replayOptions.errorReplayDuration
                 startedAt:replayStart];

    self->_isFullSession = YES;
}

- (void)updateEvent:(SentryEvent *)event withReplayId:(SentryId *)sentryId
{
    NSMutableDictionary *context = [NSMutableDictionary dictionaryWithDictionary:event.context];
    context[@"replay_id"] = sentryId;
    event.context = context;
}

- (void)newFrame:(CADisplayLink *)sender
{
    NSDate *now = [self dateProvider].date;

    if ([now timeIntervalSinceDate:_lastScreenShot] > 1) {
        [self takeScreenshot];
        _lastScreenShot = now;

        if (_videoSegmentStart == nil) {
            _videoSegmentStart = now;
        } else if (_isFullSession &&
            [now timeIntervalSinceDate:_videoSegmentStart]
                >= _replayOptions.sessionSegmentDuration) {
            [self prepareSegmentUntil:now];
        }
    }
}

- (void)prepareSegmentUntil:(NSDate *)date
{
    NSTimeInterval from = [_videoSegmentStart timeIntervalSinceDate:_sessionStart];
    NSTimeInterval to = [date timeIntervalSinceDate:_sessionStart];
    NSURL *pathToSegment = [_urlToCache URLByAppendingPathComponent:@"segments"];

    if (![NSFileManager.defaultManager fileExistsAtPath:pathToSegment.path]) {
        NSError *error;
        if (![NSFileManager.defaultManager createDirectoryAtPath:pathToSegment.path
                                     withIntermediateDirectories:YES
                                                      attributes:nil
                                                           error:&error]) {
            SENTRY_LOG_ERROR(@"Can't create session replay segment folder. Error: %@",
                error.localizedDescription);
            return;
        }
    }

    pathToSegment = [pathToSegment
        URLByAppendingPathComponent:[NSString stringWithFormat:@"%f-%f.mp4", from, to]];

    NSDate *segmentStart =
        [[self dateProvider].date dateByAddingTimeInterval:-_replayOptions.sessionSegmentDuration];

    [self createAndCapture:pathToSegment
                  duration:_replayOptions.sessionSegmentDuration
                 startedAt:segmentStart];
}

- (void)createAndCapture:(NSURL *)videoUrl
                duration:(NSTimeInterval)duration
               startedAt:(NSDate *)start
{

    if (sessionReplayId == nil) {
        sessionReplayId = [[SentryId alloc] init];
    }
    [_replayMaker
        createVideoWithDuration:duration
                      beginning:start
                  outputFileURL:videoUrl
                          error:nil
                     completion:^(SentryVideoInfo *videoInfo, NSError *error) {
                         if (error != nil) {
                             SENTRY_LOG_ERROR(@"Could not create replay video - %@", error);
                         } else {
                             [self captureSegment:self->_currentSegmentId++
                                            video:videoInfo
                                         replayId:self->sessionReplayId
                                       replayType:kSentryReplayTypeSession];

                             [self->_replayMaker releaseFramesUntil:videoInfo.end];
                             self->_videoSegmentStart = nil;
                         }
                     }];
}

- (void)captureSegment:(NSInteger)segment
                 video:(SentryVideoInfo *)videoInfo
              replayId:(SentryId *)replayid
            replayType:(SentryReplayType)replayType
{
    SentryReplayEvent *replayEvent = [[SentryReplayEvent alloc] init];
    replayEvent.replayType = replayType;
    replayEvent.eventId = replayid;
    replayEvent.replayStartTimestamp = videoInfo.start;
    replayEvent.segmentId = segment;
    replayEvent.timestamp = videoInfo.end;

    SentryReplayRecording *recording =
        [[SentryReplayRecording alloc] initWithSegmentId:replayEvent.segmentId
                                                    size:videoInfo.fileSize
                                                   start:videoInfo.start
                                                duration:videoInfo.duration
                                              frameCount:videoInfo.frameCount
                                               frameRate:videoInfo.frameRate
                                                  height:videoInfo.height
                                                   width:videoInfo.width];

    [SentrySDK.currentHub captureReplayEvent:replayEvent
                             replayRecording:recording
                                       video:videoInfo.path];
}

- (void)takeScreenshot
{
    if (_processingScreenshot) {
        return;
    }
    @synchronized(self) {
        if (_processingScreenshot) {
            return;
        }
        _processingScreenshot = YES;
    }

    UIImage *screenshot = [SentryViewPhotographer.shared imageWithView:_rootView];

    _processingScreenshot = NO;

    dispatch_queue_t backgroundQueue
        = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(backgroundQueue, ^{ [self->_replayMaker addFrameWithImage:screenshot]; });
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
