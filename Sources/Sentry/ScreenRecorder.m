
#import "ScreenRecorder.h"
#import <AVFoundation/AVFoundation.h>

@implementation ScreenRecorder {
    AVAssetWriter *videoWriter;
    AVAssetWriterInput* videoWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *adaptor;
    UIView *_view;
    int frameCount;
    NSTimer *captureTimer;
    UIGraphicsImageRenderer* renderer;
    CGContextRef context;
    CVPixelBufferRef pxbuffer;
    NSURL* _targetFile;
    NSDate * _endBy;
    NSDate * _startedAt;
}


-(instancetype)init {
    self = [super init];
    return self;
}

-(bool) startWithTarget:(NSURL *)target {
    return [self startWithTarget:target duration:0];
}

-(bool) startWithTarget:(NSURL *)target
               duration:(NSTimeInterval)duration
{
    if (UIApplication.sharedApplication.windows.count == 0) return false;
    
    _view = UIApplication.sharedApplication.windows[0];
    _targetFile = target;
    
    NSError *error = nil;
    
    videoWriter = [[AVAssetWriter alloc] initWithURL:target fileType:AVFileTypeMPEG4
                                               error:&error];
    
    if (error != nil) return false;
    
    if (@available(iOS 11.0, *)) {
        NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                       AVVideoCodecTypeH264, AVVideoCodecKey,
                                       [NSNumber numberWithInt:(int)_view.frame.size.width], AVVideoWidthKey,
                                       [NSNumber numberWithInt:(int)_view.frame.size.height], AVVideoHeightKey,
                                       nil];
        
        videoWriterInput = [AVAssetWriterInput
                            assetWriterInputWithMediaType:AVMediaTypeVideo
                            outputSettings:videoSettings];
    } else {
        return false;
    }
    
    adaptor = [AVAssetWriterInputPixelBufferAdaptor
               assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput
               sourcePixelBufferAttributes:nil];
    
    videoWriterInput.expectsMediaDataInRealTime = YES;
    [videoWriter addInput:videoWriterInput];
    
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    frameCount = 0;
    
    captureTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/15.0 target:self selector:@selector(tick) userInfo:nil repeats:true];
    
    //UIGraphicsImageRendererFormat * format = [[UIGraphicsImageRendererFormat alloc] init];
    //format.scale = 1;
    
    //renderer = [[UIGraphicsImageRenderer alloc] initWithSize:_view.frame.size format:format];
    if (context == nil) {
        context = [self createContext:_view.frame.size];
    }
    _startedAt = [NSDate date];
    _endBy = [NSDate dateWithTimeIntervalSinceNow:duration > 0 ? duration : 3600 ];
    
    return context != NULL;
    return NULL;
}


-(void) finish {
    [captureTimer invalidate];
    captureTimer = nil;
    
    [videoWriterInput markAsFinished];
    [videoWriter finishWritingWithCompletionHandler:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"io.sentry.RECORD_ENDED" object:nil];
    }];
}

-(void)tick {
    if ([_endBy timeIntervalSinceNow] < 0) {
        [self finish];
    } else if (adaptor.assetWriterInput.readyForMoreMediaData) {
        if (captureTimer == nil) return;
        UIGraphicsPushContext(context);
        [_view drawViewHierarchyInRect:_view.bounds afterScreenUpdates:false];
        UIGraphicsPopContext();
        [self writeNewFrame];
    }
}

- (bool)writeNewFrame {
    CMTime frameTime = CMTimeMake(frameCount,(int32_t) 15);
    frameCount++;
    bool res = [adaptor appendPixelBuffer:pxbuffer withPresentationTime:frameTime];
    return res;
}

+(ScreenRecorder*) shared {
    static ScreenRecorder * _shared;
    if (_shared == nil) {
        _shared = [[ScreenRecorder alloc] init];
    }
    return _shared;
}

-(BOOL)isRecording {
    return captureTimer != nil;
}

- (CGContextRef) createContext:(CGSize) size {
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, (int)size.width,
                                          (int)size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    size_t bpr = CVPixelBufferGetBytesPerRow(pxbuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef _context = CGBitmapContextCreate(pxdata, (int)size.width,
                                                  (int)size.height, 8, bpr, rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    CGContextConcatCTM(_context, CGAffineTransformMakeTranslation(0, (int)size.height));
    CGContextConcatCTM(_context, CGAffineTransformMakeScale(1, -1));
    
    return _context;
}

-(NSTimeInterval) recordingLength {
    return -[_startedAt timeIntervalSinceNow];
}

@end
