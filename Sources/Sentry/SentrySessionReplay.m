#import "SentrySessionReplay.h"
#import "SentryAttachment+Private.h"
#import "SentryDependencyContainer.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryFileManager.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentryRandom.h"
#import "SentryReplayEvent.h"
#import "SentryReplayRecording.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"

#if SENTRY_HAS_UIKIT && !TARGET_OS_VISION

NS_ASSUME_NONNULL_BEGIN

@interface
SentrySessionReplay ()

@property (nonatomic) BOOL isRunning;

@property (nonatomic) BOOL isFullSession;

@end

@implementation SentrySessionReplay {
    NSURL *_urlToCache;
    UIView *_rootView;
    NSDate *_lastScreenShot;
    NSDate *_videoSegmentStart;
    NSDate *_sessionStart;
    NSMutableArray<UIImage *> *imageCollection;
    SentryId *sessionReplayId;
    SentryReplayOptions *_replayOptions;
    SentryOnDemandReplay *_replayMaker;
    SentryDisplayLinkWrapper *_displayLink;
    SentryCurrentDateProvider *_dateProvider;
    id<SentryRandom> _sentryRandom;
    id<SentryViewScreenshotProvider> _screenshotProvider;
    int _currentSegmentId;
    BOOL _processingScreenshot;
    BOOL _reachedMaximumDuration;
}

- (instancetype)initWithSettings:(SentryReplayOptions *)replayOptions
                replayFolderPath:(NSURL *)folderPath
              screenshotProvider:(id<SentryViewScreenshotProvider>)screenshotProvider
                     replayMaker:(id<SentryReplayMaker>)replayMaker
                    dateProvider:(SentryCurrentDateProvider *)dateProvider
                          random:(id<SentryRandom>)random
              displayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper;
{
    if (self = [super init]) {
        _replayOptions = replayOptions;
        _dateProvider = dateProvider;
        _sentryRandom = random;
        _screenshotProvider = screenshotProvider;
        _displayLink = displayLinkWrapper;
        _isRunning = NO;
        _urlToCache = folderPath;
        _replayMaker = replayMaker;
        _reachedMaximumDuration = NO;
    }
    return self;
}

- (void)start:(UIView *)rootView fullSession:(BOOL)full
{
    if (rootView == nil) {
        SENTRY_LOG_DEBUG(@"rootView cannot be nil. Session replay will not be recorded.");
        return;
    }

    if (_isRunning) {
        return;
    }

    @synchronized(self) {
        if (_isRunning) {
            return;
        }
        [_displayLink linkWithTarget:self selector:@selector(newFrame:)];
        _isRunning = YES;
    }

    _rootView = rootView;
    _lastScreenShot = _dateProvider.date;
    _videoSegmentStart = nil;
    _currentSegmentId = 0;
    sessionReplayId = [[SentryId alloc] init];

    imageCollection = [NSMutableArray array];
    if (full) {
        [self startFullReplay];
    }
}

- (void)startFullReplay
{
    _sessionStart = _lastScreenShot;
    _isFullSession = YES;
}

- (void)stop
{
    @synchronized(self) {
        [_displayLink invalidate];
        _isRunning = NO;
    }
}

- (void)captureReplayForEvent:(SentryEvent *)event;
{
    if (_isFullSession || !_isRunning) {
        return;
    }

    if (event.error == nil && (event.exceptions == nil || event.exceptions.count == 0)) {
        return;
    }

    if ([_sentryRandom nextNumber] > _replayOptions.errorSampleRate) {
        return;
    }

    NSURL *finalPath = [_urlToCache URLByAppendingPathComponent:@"replay.mp4"];
    NSDate *replayStart =
        [_dateProvider.date dateByAddingTimeInterval:-_replayOptions.errorReplayDuration];

    [self createAndCapture:finalPath
                  duration:_replayOptions.errorReplayDuration
                 startedAt:replayStart];

    [self startFullReplay];
}

- (void)newFrame:(CADisplayLink *)sender
{
    if (!_isRunning) {
        return;
    }

    NSDate *now = _dateProvider.date;

    if (_isFullSession &&
        [now timeIntervalSinceDate:_sessionStart] > _replayOptions.maximumDuration) {
        _reachedMaximumDuration = YES;
        [self prepareSegmentUntil:now];
        [self stop];
        return;
    }

    if ([now timeIntervalSinceDate:_lastScreenShot] >= 1) {
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
        URLByAppendingPathComponent:[NSString stringWithFormat:@"%i.mp4", _currentSegmentId]];

    NSDate *segmentStart =
        [_dateProvider.date dateByAddingTimeInterval:-_replayOptions.sessionSegmentDuration];

    [self createAndCapture:pathToSegment
                  duration:_replayOptions.sessionSegmentDuration
                 startedAt:segmentStart];
}

- (void)createAndCapture:(NSURL *)videoUrl
                duration:(NSTimeInterval)duration
               startedAt:(NSDate *)start
{
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

    NSError *error;
    if (![NSFileManager.defaultManager removeItemAtURL:videoInfo.path error:&error]) {
        SENTRY_LOG_ERROR(@"Cound not delete replay segment from disk: %@", error);
    }
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

    [_screenshotProvider imageWithView:_rootView
                               options:_replayOptions
                            onComplete:^(UIImage *screenshot) {
                                self->_processingScreenshot = NO;
                                [self->_replayMaker addFrameWithImage:screenshot];
                            }];
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
