#import "SentrySessionReplay.h"
#import "SentryAttachment+Private.h"
#import "SentryLog.h"
#import "SentryOndemandReplay.h"
#import "SentryReplaySettings+Private.h"
#import "SentryViewPhotographer.h"

@implementation SentrySessionReplay {
    UIView *_rootView;
    BOOL _processingScreenshot;
    CADisplayLink *_displayLink;
    NSDate *_lastScreenShot;
    NSDate *_videoSegmentStart;
    NSURL *_urlToCache;
    NSDate *_sessionStart;
    SentryReplaySettings *_settings;
    SentryOnDemandReplay *_replayMaker;

    NSMutableArray<UIImage *> *imageCollection;
}

- (instancetype)initWithSettings:(SentryReplaySettings *)replaySettings
{
    if (self = [super init]) {
        _settings = replaySettings;
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
        _replayMaker.bitRate = _settings.replayBitRate;
        _replayMaker.cacheMaxSize = full ? NSUIntegerMax : 32;
        imageCollection = [NSMutableArray array];

        NSLog(@"Recording session to %@", _urlToCache);
    }
}

- (void)stop
{
    [_displayLink invalidate];
    _displayLink = nil;
}

- (NSArray<SentryAttachment *> *)processAttachments:(NSArray<SentryAttachment *> *)attachments
                                           forEvent:(nonnull SentryEvent *)event
{
    if (event.error == nil && (event.exceptions == nil || event.exceptions.count == 0)) {
        return attachments;
    }

    NSLog(@"Recording session event id %@", event.eventId);
    NSMutableArray<SentryAttachment *> *result = [NSMutableArray arrayWithArray:attachments];

    NSURL *finalPath = [_urlToCache URLByAppendingPathComponent:@"replay.mp4"];

    dispatch_group_t _wait_for_render = dispatch_group_create();

    dispatch_group_enter(_wait_for_render);
    [_replayMaker createVideoOf:30
                           from:[NSDate dateWithTimeIntervalSinceNow:-30]
                  outputFileURL:finalPath
                     completion:^(BOOL success, NSError *_Nonnull error) {
                         dispatch_group_leave(_wait_for_render);
                     }];
    dispatch_group_wait(_wait_for_render, DISPATCH_TIME_FOREVER);

    SentryAttachment *attachment = [[SentryAttachment alloc] initWithPath:finalPath.path
                                                                 filename:@"replay.mp4"
                                                              contentType:@"video/mp4"];

    [result addObject:attachment];

    return result;
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

    dispatch_group_t _wait_for_render = dispatch_group_create();

    dispatch_group_enter(_wait_for_render);
    [_replayMaker createVideoOf:5
                           from:[date dateByAddingTimeInterval:-5]
                  outputFileURL:pathToSegment
                     completion:^(BOOL success, NSError *_Nonnull error) {
                         dispatch_group_leave(_wait_for_render);

                         // Need to send the segment here

                         [self->_replayMaker releaseFramesUntil:date];
                         self->_videoSegmentStart = nil;
                     }];
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
