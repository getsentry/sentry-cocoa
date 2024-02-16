#import "SentryOnDemandReplay.h"

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "SentryLog.h"
@interface SentryReplayFrame : NSObject

@property (nonatomic, strong) NSString *imagePath;
@property (nonatomic, strong) NSDate *time;

-(instancetype) initWithPath:(NSString *)path time:(NSDate*)time;

@end

@implementation SentryReplayFrame
-(instancetype) initWithPath:(NSString *)path time:(NSDate*)time {
    if (self = [super init]) {
        self.imagePath = path;
        self.time = time;
    }
    return self;
}

@end

@implementation SentryOnDemandReplay
{
    NSString * _outputPath;
    NSDate * _startTime;
    NSMutableArray<SentryReplayFrame *> * _frames;
    CGSize _videoSize;
    dispatch_queue_t _onDemandDispatchQueue;
}

- (instancetype)initWithOutputPath:(NSString *)outputPath {
    if (self = [super init]) {
        _outputPath = outputPath;
        _startTime = [[NSDate alloc] init];
        _frames = [NSMutableArray array];
        //_videoSize = CGSizeMake(300, 651);
        _videoSize = CGSizeMake(200, 434);
        _bitRate = 20000;
        _cacheMaxSize = NSUIntegerMax;
        _onDemandDispatchQueue = dispatch_queue_create("io.sentry.sessionreplay.ondemand", NULL);
        
    }
    return self;
}

- (void)addFrame:(UIImage *)image {
    dispatch_async(_onDemandDispatchQueue, ^{
        NSData * data = UIImagePNGRepresentation([self resizeImage:image withMaxWidth:300]);
        NSDate* date = [[NSDate alloc] init];
        NSTimeInterval interval = [date timeIntervalSinceDate:self->_startTime];
        NSString *imagePath = [self->_outputPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%lf.png", interval]];
        
        [data writeToFile:imagePath atomically:YES];
        
        SentryReplayFrame *frame = [[SentryReplayFrame alloc] initWithPath:imagePath time:date];
        [self->_frames addObject:frame];
        
        while (self->_frames.count > self->_cacheMaxSize) {
            [self removeOldestFrame];
        }
    });
}

- (UIImage *)resizeImage:(UIImage *)originalImage withMaxWidth:(CGFloat)maxWidth {
    CGSize originalSize = originalImage.size;
    CGFloat aspectRatio = originalSize.width / originalSize.height;

    CGFloat newWidth = MIN(originalSize.width, maxWidth);
    CGFloat newHeight = newWidth / aspectRatio;

    CGSize newSize = CGSizeMake(newWidth, newHeight);

    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1);
    [originalImage drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return resizedImage;
}

- (void)releaseFramesUntil:(NSDate *)date {
    dispatch_async(_onDemandDispatchQueue, ^{
        while (self->_frames.count > 0 && [self->_frames.firstObject.time compare:date] != NSOrderedDescending) {
            [self removeOldestFrame];
        }
    });
}

- (void)removeOldestFrame {
    NSError * error;
    if (![NSFileManager.defaultManager removeItemAtPath:_frames.firstObject.imagePath error:&error]){
        SENTRY_LOG_DEBUG(@"Could not delete replay frame at: %@. %@",_frames.firstObject.imagePath, error);
    }
    [_frames removeObjectAtIndex:0];
}

- (void)createVideoOf:(NSTimeInterval)duration from:(NSDate *)beginning
        outputFileURL:(NSURL *)outputFileURL
           completion:(void (^)(BOOL success, NSError *error))completion {
    // Set up AVAssetWriter with appropriate settings
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:outputFileURL
                                                           fileType:AVFileTypeQuickTimeMovie
                                                              error:nil];
    
    NSDictionary *videoSettings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(_videoSize.width),
        AVVideoHeightKey: @(_videoSize.height),
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @(_bitRate),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
        },
    };
    
    AVAssetWriterInput *videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    NSDictionary *bufferAttributes = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB),
    };
    
    AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput sourcePixelBufferAttributes:bufferAttributes];
    
    [videoWriter addInput:videoWriterInput];
    
    // Start writing video
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    NSDate* end = [beginning dateByAddingTimeInterval:duration];
    __block NSInteger frameCount = 0;
    NSMutableArray<NSString *> * frames = [NSMutableArray array];
    for (SentryReplayFrame *frame in self->_frames) {
       if ([frame.time compare:beginning] == NSOrderedAscending) {
            continue;;
        } else if ([frame.time compare:end] == NSOrderedDescending) {
            break;
        }
        [frames addObject:frame.imagePath];
    }
    
    [videoWriterInput requestMediaDataWhenReadyOnQueue:_onDemandDispatchQueue usingBlock:^{
        UIImage *image = [UIImage imageWithContentsOfFile:frames[frameCount]];
        if (image) {
            CMTime presentTime = CMTimeMake(frameCount++, 1);
            
            if (![self appendPixelBufferForImage:image pixelBufferAdaptor:pixelBufferAdaptor presentationTime:presentTime]) {
                if (completion) {
                    completion(NO, videoWriter.error);
                }
            }
        }
    
        if (frameCount >= frames.count){
            [videoWriterInput markAsFinished];
            [videoWriter finishWritingWithCompletionHandler:^{
                if (completion) {
                    completion(videoWriter.status == AVAssetWriterStatusCompleted, videoWriter.error);
                }
            }];
        }
    }];
}

- (BOOL)appendPixelBufferForImage:(UIImage *)image pixelBufferAdaptor:(AVAssetWriterInputPixelBufferAdaptor *)pixelBufferAdaptor presentationTime:(CMTime)presentationTime {
    CVReturn status = kCVReturnSuccess;
    
    CVPixelBufferRef pixelBuffer = NULL;
    status = CVPixelBufferCreate(kCFAllocatorDefault, (size_t)image.size.width, (size_t)image.size.height, kCVPixelFormatType_32ARGB, NULL, &pixelBuffer);
    
    if (status != kCVReturnSuccess) {
        return NO;
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *pixelData = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixelData, (size_t)image.size.width, (size_t)image.size.height, 8, CVPixelBufferGetBytesPerRow(pixelBuffer), rgbColorSpace, (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    
    CGContextTranslateCTM(context, 0, image.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    UIGraphicsPushContext(context);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIGraphicsPopContext();
    
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    // Append the pixel buffer with the current image to the video
    BOOL success = [pixelBufferAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:presentationTime];
    
    CVPixelBufferRelease(pixelBuffer);
    
    return success;
}


@end
#endif //SENTRY_HAS_UIKIT
