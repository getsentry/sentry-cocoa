#import "SentrySessionReplay.h"
#import "SentryVideoReplay.h"
#import "SentryImagesReplay.h"
#import "SentryViewPhotographer.h"
#import "SentryOndemandReplay.h"
#import "SentryAttachment+Private.h"
#import "SentryLog.h"
#import "SentryTouchesTracker.h"
//#define use_video 1
#define use_ondemand 1

@implementation SentrySessionReplay {
    UIView * _rootView;
    BOOL _processingScreenshot;
    CADisplayLink * _displayLink;
    NSDate * _lastScreenShot;
    NSDate * _videoSegmentStart;
    NSURL * _urlToCache;
    NSDate * _sessionStart;
    SentryReplaySettings * _settings;
#if use_video
    SentryVideoReplay * replayMaker;
#elif use_ondemand
    SentryOnDemandReplay * _replayMaker;
#else
    SentryImagesReplay * replayMaker;
#endif
    
    NSMutableArray<UIImage *>* imageCollection;
    SentryTouchesTracker * _touchesTracker;
}

- (instancetype)initWithSettings:(SentryReplaySettings *)replaySettings {
    if (self = [super init]) {
        _settings = replaySettings;
    }
    return self;
}

- (void)start:(UIView *)rootView fullSession:(BOOL)full {
    if (rootView == nil) {
        SENTRY_LOG_DEBUG(@"rootView cannot be nil. Session replay will not be recorded.");
        return;
    }
    
    @synchronized (self) {
        if (_displayLink == nil) {
            _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(newFrame:)];
            [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        } else {
            //Session display is already running.
            return;
        }
        
        _rootView = rootView;
        _lastScreenShot = [[NSDate alloc] init];
        _videoSegmentStart = nil;
        _sessionStart = _lastScreenShot;
        _touchesTracker = [[SentryTouchesTracker alloc] init];
        [_touchesTracker start];
        
        NSURL * docs = [[NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"io.sentry"];
        
        NSString * currentSession = [NSUUID UUID].UUIDString;
        _urlToCache = [docs URLByAppendingPathComponent:currentSession];
        
        if (![NSFileManager.defaultManager fileExistsAtPath:_urlToCache.path]) {
            [NSFileManager.defaultManager createDirectoryAtURL:_urlToCache withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        _replayMaker =
#if use_video
        [[SentryVideoReplay alloc] initWithOutputPath:[urlToCache URLByAppendingPathComponent:@"sr.mp4"].path frameSize:rootView.frame.size framesPerSec:1];
#elif use_ondemand
        [[SentryOnDemandReplay alloc] initWithOutputPath:_urlToCache.path];
        _replayMaker.bitRate = _settings.replayBitRate;
        _replayMaker.cacheMaxSize = full ? NSUIntegerMax : 32;
#else
        [[SentryImagesReplay alloc] initWithOutputPath:urlToCache.path];
#endif
        imageCollection = [NSMutableArray array];
        
        NSLog(@"Recording session to %@",_urlToCache);
    }
}

- (void)stop {
    [_displayLink invalidate];
    _displayLink = nil;
#ifdef use_video
    [videoReplay finalizeVideoWithCompletion:^(BOOL success, NSError * _Nonnull error) {
        if (!success) {
            NSLog(@"%@", error);
        }
    }];
#endif
}

- (NSArray<SentryAttachment *> *)processAttachments:(NSArray<SentryAttachment *> *)attachments
                                           forEvent:(nonnull SentryEvent *)event
{
#if use_ondemand
    if (event.error == nil && (event.exceptions == nil || event.exceptions.count == 0)) {
        return attachments;
    }
    
    NSLog(@"Recording session event id %@", event.eventId);
    NSMutableArray<SentryAttachment *> *result = [NSMutableArray arrayWithArray:attachments];
    
    NSURL * finalPath  = [_urlToCache URLByAppendingPathComponent:@"replay.mp4"];
    
    dispatch_group_t _wait_for_render = dispatch_group_create();
    
    dispatch_group_enter(_wait_for_render);
    [_replayMaker createVideoOf:30
                          from:[NSDate dateWithTimeIntervalSinceNow:-30]
                 outputFileURL:finalPath
                    completion:^(BOOL success, NSError * _Nonnull error) {
        dispatch_group_leave(_wait_for_render);
    }];
    dispatch_group_wait(_wait_for_render, DISPATCH_TIME_FOREVER);
    
    SentryAttachment *attachment =
        [[SentryAttachment alloc] initWithPath:finalPath.path
                                      filename:@"replay.mp4"
                                   contentType:@"video/mp4"];

    [result addObject:attachment];
    
    return result;
#else
    return attachments;
#endif
}

- (void)sendReplayForEvent:(SentryEvent *)event {
#if use_ondemand
    
#endif
}

- (void)newFrame:(CADisplayLink *)sender {
    NSDate * now = [[NSDate alloc] init];
    
    if ([now timeIntervalSinceDate:_lastScreenShot] > 1) {
        [self takeScreenshot];
        _lastScreenShot = now;
        
        if (_videoSegmentStart == nil) {
            _videoSegmentStart = now;
        } else if ([now timeIntervalSinceDate:_videoSegmentStart] >= 5) {
            [self prepareSegmentUntil: now];
        }
    }
}

- (void)prepareSegmentUntil:(NSDate *)date {
    NSTimeInterval from = [_videoSegmentStart timeIntervalSinceDate:_sessionStart];
    NSTimeInterval to = [date timeIntervalSinceDate:_sessionStart];
    NSURL * pathToSegment = [_urlToCache URLByAppendingPathComponent:@"segments"];
    
    if (![NSFileManager.defaultManager fileExistsAtPath:pathToSegment.path]) {
        NSError * error;
        if (![NSFileManager.defaultManager createDirectoryAtPath:pathToSegment.path withIntermediateDirectories:YES attributes:nil error:&error]){
            SENTRY_LOG_ERROR(@"Can't create session replay segment folder. Error: %@", error.localizedDescription);
            return;
        }
    }
    
    pathToSegment = [pathToSegment URLByAppendingPathComponent:[NSString stringWithFormat:@"%f-%f.mp4",from, to]];
    
    dispatch_group_t _wait_for_render = dispatch_group_create();
    
    dispatch_group_enter(_wait_for_render);
    [_replayMaker createVideoOf:5
                          from:[date dateByAddingTimeInterval:-5]
                 outputFileURL:pathToSegment
                    completion:^(BOOL success, NSError * _Nonnull error) {
        dispatch_group_leave(_wait_for_render);
                
        //Need to send the segment here
        
        [self->_replayMaker releaseFramesUntil:date];
        self->_videoSegmentStart = nil;
    }];
   
}

- (void)takeScreenshot {
    if (_processingScreenshot) { return; }
    @synchronized (self) {
        if (_processingScreenshot) { return; }
        _processingScreenshot = YES;
    }
       
    UIImage* screenshot = [SentryViewPhotographer.shared imageFromUIView:_rootView];
    
    _processingScreenshot = NO;
 
    dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(backgroundQueue, ^{
#if use_video
        [self->replayMaker addFrame:screenshot withCompletion:^(BOOL success, NSError * _Nonnull error) {
            
        }];
#else
        [self->_replayMaker addFrame:screenshot];
#endif
    });
}

@end
