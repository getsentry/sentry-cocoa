#import "SentrySessionReplay.h"
#import "SentryAttachment+Private.h"
#import "SentryHub+Private.h"
#import "SentryId.h"
#import "SentryLog.h"
#import "SentryOnDemandReplay.h"
#import "SentryReplayEvent.h"
#import "SentryReplayRecording.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"
#import "SentryViewPhotographer.h"

#if SENTRY_HAS_UIKIT

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
}

- (instancetype)initWithSettings:(SentryReplayOptions *)replayOptions
{
    if (self = [super init]) {
        _replayOptions = replayOptions;
    }
    return self;
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

        NSURL *docs = [[NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory
                                                            inDomains:NSUserDomainMask]
                           .firstObject URLByAppendingPathComponent:@"io.sentry"];

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
        _replayMaker.cacheMaxSize = full ? NSUIntegerMax : 32;
        imageCollection = [NSMutableArray array];

        NSLog(@"Recording session to %@", _urlToCache);

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

// TODO: dont use processAttachments to capture replay
- (nullable NSArray<SentryAttachment *> *)processAttachments:
                                              (nullable NSArray<SentryAttachment *> *)attachments
                                                    forEvent:(nonnull SentryEvent *)event
{
    if (event.error == nil && (event.exceptions == nil || event.exceptions.count == 0)) {
        return attachments;
    }

    NSURL *finalPath = [_urlToCache URLByAppendingPathComponent:@"replay.mp4"];
    NSDate *replayStart = [NSDate dateWithTimeIntervalSinceNow:-30];

    [_replayMaker createVideoOf:30
                           from:replayStart
                  outputFileURL:finalPath
                     completion:^(SentryVideoInfo *videoInfo, NSError *_Nonnull error) {
                         [self captureSegment:videoInfo
                                     videoUrl:finalPath
                                    startedAt:replayStart
                                     replayId:[[SentryId alloc] init]];
                     }];
    return attachments;
}

- (void)sendReplayForEvent:(SentryEvent *)event
{
}

- (void)newFrame:(CADisplayLink *)sender
{
    NSDate *now = [[NSDate alloc] init];

    if ([now timeIntervalSinceDate:_lastScreenShot] > 1) {
        [self takeScreenshot];
        _lastScreenShot = now;

        if (_videoSegmentStart == nil) {
            _videoSegmentStart = now;
        } else if ([now timeIntervalSinceDate:_videoSegmentStart] >= 5) {
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

    NSDate *segmentStart = [date dateByAddingTimeInterval:-5];

    [_replayMaker createVideoOf:5
                           from:segmentStart
                  outputFileURL:pathToSegment
                     completion:^(SentryVideoInfo *videoInfo, NSError *_Nonnull error) {
                         //[self captureSegment:videoInfo videoUrl:pathToSegment
                         //startedAt:segmentStart replayId:self->sessionReplayId];

                         [self->_replayMaker releaseFramesUntil:date];
                         self->_videoSegmentStart = nil;
                     }];
}

- (void)captureSegment:(SentryVideoInfo *)videoInfo
              videoUrl:(NSURL *)filePath
             startedAt:(NSDate *)replayStart
              replayId:(SentryId *)replayid
{
    SentryReplayEvent *replayEvent = [[SentryReplayEvent alloc] init];
    replayEvent.replayType = kSentryReplayTypeBuffer;
    replayEvent.eventId = replayid;
    replayEvent.replayStartTimestamp = replayStart;
    replayEvent.segmentId = 0;

    SentryReplayRecording *recording =
        [[SentryReplayRecording alloc] initWithSegmentId:replayEvent.segmentId
                                                    size:1
                                                   start:replayStart
                                                duration:videoInfo.duration
                                              frameCount:videoInfo.frameCount
                                               frameRate:videoInfo.frameRate
                                                  height:videoInfo.height
                                                   width:videoInfo.width];

    [SentrySDK.currentHub captureReplayEvent:replayEvent replayRecording:recording video:filePath];

    SENTRY_LOG_DEBUG(@"Session replay: ReplayId: %@ \nAT: %@", replayEvent.eventId, filePath);
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

    UIImage *screenshot = [SentryViewPhotographer.shared imageFromUIView:_rootView];

    _processingScreenshot = NO;

    dispatch_queue_t backgroundQueue
        = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(backgroundQueue, ^{ [self->_replayMaker addFrame:screenshot]; });
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
