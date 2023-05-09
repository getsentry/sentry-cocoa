#import "SentryScreenshot.h"
#import "SentryCompiler.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryUIApplication.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
@import Vision;

@interface
SentryScreenshot ()

- (void)removePII:(CGContextRef)context API_AVAILABLE(ios(13.0), tvos(13.0));

@end

@implementation SentryScreenshot

- (NSArray<NSData *> *)appScreenshots
{
    __block NSArray *result;

    void (^takeScreenShot)(void) = ^{ result = [self takeScreenshots]; };

    [[SentryDependencyContainer sharedInstance].dispatchQueueWrapper
        dispatchSyncOnMainQueue:takeScreenShot];

    return result;
}

- (void)saveScreenShots:(NSString *)imagesDirectoryPath
{
    // This function does not dispatch the screenshot to the main thread.
    // The caller should be aware of that.
    // We did it this way because we use this function to save screenshots
    // during signal handling, and if we dispatch it to the main thread,
    // that is probably blocked by the crash event, we freeze the application.
    [[self takeScreenshots] enumerateObjectsUsingBlock:^(NSData *obj, NSUInteger idx, BOOL *stop) {
        NSString *name = idx == 0
            ? @"screenshot.png"
            : [NSString stringWithFormat:@"screenshot-%li.png", (unsigned long)idx + 1];
        NSString *fileName = [imagesDirectoryPath stringByAppendingPathComponent:name];
        [obj writeToFile:fileName atomically:YES];
    }];
}

- (void)removePII:(CGContextRef)context
{
    CGImageRef image = CGBitmapContextCreateImage(context);
    VNImageRequestHandler *imageHandler = [[VNImageRequestHandler alloc] initWithCGImage:image
                                                                                 options:@{}];

    __block VNRequest *requestResult = nil;

    VNRecognizeTextRequest *textRequest =
        [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(
            VNRequest *_Nonnull request, NSError *_Nullable error) { requestResult = request; }];

    NSError *error;
    [imageHandler performRequests:@[ textRequest ] error:&error];

    CGImageRelease(image);

    if (requestResult == nil) {
        return;
    }

    UIGraphicsPushContext(context);
    CGRect contextRect = CGContextGetClipBoundingBox(context);
    CGContextScaleCTM(context, 1, -1);
    CGContextTranslateCTM(context, 0, -contextRect.size.height);

    CGContextSetFillColorWithColor(context, UIColor.blackColor.CGColor);

    for (VNRecognizedTextObservation *observartion in requestResult.results) {
        VNRecognizedText *candidate = [[observartion topCandidates:1] firstObject];
        if (candidate == nil)
            continue;

        NSRange range = NSMakeRange(0, candidate.string.length);
        VNRectangleObservation *candidateBox = [candidate boundingBoxForRange:range error:nil];

        CGRect maskBox = VNImageRectForNormalizedRect(candidateBox.boundingBox,
            (unsigned long)contextRect.size.width, (unsigned long)contextRect.size.height);

        CGContextFillRect(context, maskBox);
    }
    UIGraphicsPopContext();
}

- (NSArray<NSData *> *)takeScreenshots
{
    NSArray<UIWindow *> *windows = [SentryDependencyContainer.sharedInstance.application windows];

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:windows.count];

    for (UIWindow *window in windows) {
        CGSize size = window.frame.size;
        if (size.width == 0 || size.height == 0) {
            // avoid API errors reported as e.g.:
            // [Graphics] Invalid size provided to UIGraphicsBeginImageContext(): size={0, 0},
            // scale=1.000000
            continue;
        }
        UIGraphicsBeginImageContext(size);

        if ([window drawViewHierarchyInRect:window.bounds afterScreenUpdates:false]) {

            if (@available(iOS 13.0, tvOS 13.0, *)) {
                [self removePII:UIGraphicsGetCurrentContext()];
            }

            UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
            // this shouldn't happen now that we discard windows with either 0 height or 0 width,
            // but still, we shouldn't send any images with either one.
            if (LIKELY(img.size.width > 0 && img.size.height > 0)) {
                NSData *bytes = UIImagePNGRepresentation(img);
                if (bytes && bytes.length > 0) {
                    [result addObject:bytes];
                }
            }
        }

        UIGraphicsEndImageContext();
    }
    return result;
}

@end

#endif
