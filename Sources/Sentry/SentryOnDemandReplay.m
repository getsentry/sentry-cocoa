#import "SentryOnDemandReplay.h"

#if SENTRY_HAS_UIKIT
#    import "SentryLog.h"
#    import <AVFoundation/AVFoundation.h>
#    import <UIKit/UIKit.h>

@interface SentryReplayFrame : NSObject

@property (nonatomic, strong) NSString *imagePath;
@property (nonatomic, strong) NSDate *time;

- (instancetype)initWithPath:(NSString *)path time:(NSDate *)time;

@end

@implementation SentryReplayFrame
- (instancetype)initWithPath:(NSString *)path time:(NSDate *)time
{
    if (self = [super init]) {
        self.imagePath = path;
        self.time = time;
    }
    return self;
}
@end

@interface SentryPixelBuffer : NSObject
- (nullable instancetype)initWithSize:(CGSize) size;

- (BOOL)appendImage:(UIImage *)image
 pixelBufferAdaptor:(AVAssetWriterInputPixelBufferAdaptor *)pixelBufferAdaptor
   presentationTime:(CMTime)presentationTime;
@end

@implementation SentryOnDemandReplay {
    NSString *_outputPath;
    NSDate *_startTime;
    NSMutableArray<SentryReplayFrame *> *_frames;
    dispatch_queue_t _onDemandDispatchQueue;
    SentryPixelBuffer * _currentPixelBuffer;
}

- (instancetype)initWithOutputPath:(NSString *)outputPath
{
    if (self = [super init]) {
        _outputPath = outputPath;
        _startTime = [[NSDate alloc] init];
        _frames = [NSMutableArray array];
        _videoSize = CGSizeMake(200, 434);
        _bitRate = 20000;
        _cacheMaxSize = NSUIntegerMax;
        _frameRate = 1;
        _onDemandDispatchQueue = dispatch_queue_create("io.sentry.sessionreplay.ondemand", NULL);
    }
    return self;
}

- (void)addFrame:(UIImage *)image
{
    dispatch_async(_onDemandDispatchQueue, ^{
        NSData *data = UIImagePNGRepresentation([self resizeImage:image withMaxWidth:300]);
        NSDate *date = [[NSDate alloc] init];
        NSTimeInterval interval = [date timeIntervalSinceDate:self->_startTime];
        NSString *imagePath = [self->_outputPath
            stringByAppendingPathComponent:[NSString stringWithFormat:@"%lf.png", interval]];

        [data writeToFile:imagePath atomically:YES];

        SentryReplayFrame *frame = [[SentryReplayFrame alloc] initWithPath:imagePath time:date];
        [self->_frames addObject:frame];

        while (self->_frames.count > self->_cacheMaxSize) {
            [self removeOldestFrame];
        }
    });
}

- (UIImage *)resizeImage:(UIImage *)originalImage withMaxWidth:(CGFloat)maxWidth
{
    CGSize originalSize = originalImage.size;
    CGFloat aspectRatio = originalSize.width / originalSize.height;

    CGFloat newWidth = MIN(originalSize.width, maxWidth);
    CGFloat newHeight = newWidth / aspectRatio;

    CGSize newSize = CGSizeMake(newWidth, newHeight);

    UIGraphicsBeginImageContextWithOptions(newSize, NO, self.frameRate);
    [originalImage drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return resizedImage;
}

- (void)releaseFramesUntil:(NSDate *)date
{
    dispatch_async(_onDemandDispatchQueue, ^{
        while (self->_frames.count > 0 &&
            [self->_frames.firstObject.time compare:date] != NSOrderedDescending) {
            [self removeOldestFrame];
        }
    });
}

- (void)removeOldestFrame
{
    NSError *error;
    if (![NSFileManager.defaultManager removeItemAtPath:_frames.firstObject.imagePath
                                                  error:&error]) {
        SENTRY_LOG_DEBUG(
            @"Could not delete replay frame at: %@. %@", _frames.firstObject.imagePath, error);
    }
    [_frames removeObjectAtIndex:0];
}

- (void)createVideoOf:(NSTimeInterval)duration
                 from:(NSDate *)beginning
        outputFileURL:(NSURL *)outputFileURL
           completion:(void (^)(SentryVideoInfo *, NSError *error))completion
{
    // Set up AVAssetWriter with appropriate settings
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:outputFileURL
                                                           fileType:AVFileTypeQuickTimeMovie
                                                              error:nil];

    NSDictionary *videoSettings = @{
        AVVideoCodecKey : AVVideoCodecTypeH264,
        AVVideoWidthKey : @(_videoSize.width),
        AVVideoHeightKey : @(_videoSize.height),
        AVVideoCompressionPropertiesKey : @ {
            AVVideoAverageBitRateKey : @(_bitRate),
            AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel,
        },
    };

    AVAssetWriterInput *videoWriterInput =
        [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                           outputSettings:videoSettings];
    NSDictionary *bufferAttributes = @{
        (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32ARGB),
    };

    AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor
        assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput
                                   sourcePixelBufferAttributes:bufferAttributes];

    [videoWriter addInput:videoWriterInput];

    // Start writing video
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];

    NSDate *end = [beginning dateByAddingTimeInterval:duration];
    __block NSInteger frameCount = 0;
    NSMutableArray<NSString *> *frames = [NSMutableArray array];

    NSDate *start = [NSDate date];
    NSDate *actualEnd = nil;
    for (SentryReplayFrame *frame in self->_frames) {
        if ([frame.time compare:beginning] == NSOrderedAscending) {
            continue;
        } else if ([frame.time compare:end] == NSOrderedDescending) {
            break;
        }
        if ([frame.time compare:start] == NSOrderedAscending) {
            start = frame.time;
        }
        actualEnd = frame.time;
        [frames addObject:frame.imagePath];
    }
    
    _currentPixelBuffer = [[SentryPixelBuffer alloc] initWithSize:CGSizeMake(_videoSize.width, _videoSize.height)];
    
    [videoWriterInput
        requestMediaDataWhenReadyOnQueue:_onDemandDispatchQueue
                              usingBlock:^{
                                  UIImage *image =
                                      [UIImage imageWithContentsOfFile:frames[frameCount]];
                                  if (image) {
                                      CMTime presentTime = CMTimeMake(frameCount++, (int32_t)self->_frameRate);

                                      if (![self->_currentPixelBuffer appendImage:image
                                                 pixelBufferAdaptor:pixelBufferAdaptor
                                                   presentationTime:presentTime]) {
                                          if (completion) {
                                              completion(nil, videoWriter.error);
                                          }
                                      }
                                  }

                                  if (frameCount >= frames.count) {
                                      [videoWriterInput markAsFinished];
                                      [videoWriter finishWritingWithCompletionHandler:^{
                                          if (completion) {
                                              SentryVideoInfo *videoInfo = nil;
                                              if (videoWriter.status
                                                  == AVAssetWriterStatusCompleted) {
                                                  videoInfo = [[SentryVideoInfo alloc]
                                                      initWithHeight:(NSInteger)
                                                                         self->_videoSize.height
                                                               width:(NSInteger)
                                                                         self->_videoSize.width
                                                            duration:frames.count
                                                          frameCount:frames.count
                                                           frameRate:1
                                                               start:start
                                                                 end:actualEnd
                                                  ];
                                              }
                                              completion(videoInfo, videoWriter.error);
                                          }
                                      }];
                                  }
                              }];
}

@end



@implementation SentryPixelBuffer {
    CVPixelBufferRef _pixelBuffer;
    CGContextRef _context;
    CGColorSpaceRef _rgbColorSpace;
}

- (nullable instancetype)initWithSize:(CGSize) size {
    if (self = [super init]) {
        CVReturn status = kCVReturnSuccess;
        
        status = CVPixelBufferCreate(kCFAllocatorDefault, (size_t)size.width,
                                     (size_t)size.height, kCVPixelFormatType_32ARGB, NULL, &_pixelBuffer);
        
        if (status != kCVReturnSuccess) {
            return nil;
        }
        void *pixelData = CVPixelBufferGetBaseAddress(_pixelBuffer);
        _rgbColorSpace = CGColorSpaceCreateDeviceRGB();
        _context = CGBitmapContextCreate(pixelData, (size_t)size.width,
            (size_t)size.height, 8, CVPixelBufferGetBytesPerRow(_pixelBuffer), _rgbColorSpace,
            (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);

        CGContextTranslateCTM(_context, 0, size.height);
        CGContextScaleCTM(_context, 1.0, -1.0);
    }
    return self;
}

- (void)dealloc {
    CVPixelBufferRelease(_pixelBuffer);
    CGContextRelease(_context);
    CGColorSpaceRelease(_rgbColorSpace);
}

- (BOOL)appendImage:(UIImage *)image
 pixelBufferAdaptor:(AVAssetWriterInputPixelBufferAdaptor *)pixelBufferAdaptor
   presentationTime:(CMTime)presentationTime
{
    CVPixelBufferLockBaseAddress(_pixelBuffer, 0);
    
    CGContextDrawImage(_context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);
    
    CVPixelBufferUnlockBaseAddress(_pixelBuffer, 0);

    // Append the pixel buffer with the current image to the video
    BOOL success = [pixelBufferAdaptor appendPixelBuffer:_pixelBuffer
                                    withPresentationTime:presentationTime];

    return success;
}

@end
#endif // SENTRY_HAS_UIKIT
