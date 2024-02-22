#import "SentryViewPhotographer.h"

#if SENTRY_HAS_UIKIT
NS_ASSUME_NONNULL_BEGIN

@implementation SentryViewPhotographer {
    NSMutableArray<Class> *_ignoreClasses;
    NSMutableArray<Class> *_redactClasses;
}

+ (SentryViewPhotographer *)shared
{
    static SentryViewPhotographer *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ _shared = [[SentryViewPhotographer alloc] init]; });

    return _shared;
}

- (instancetype)init
{
    if (self = [super init]) {
#if TARGET_OS_IOS
        _ignoreClasses = @[ UISlider.class, UISwitch.class].mutableCopy;
#endif
        _redactClasses = @[ UILabel.class, UITextView.class, UITextField.class ].mutableCopy;

        NSArray<NSString *> *extraClasses = @[
            @"_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView",
            @"_TtC7SwiftUIP33_A34643117F00277B93DEBAB70EC0697122_UIShapeHitTestingView",
            @"SwiftUI._UIGraphicsView", @"SwiftUI.ImageLayer"
        ];

        for (NSString *className in extraClasses) {
            Class viewClass = NSClassFromString(className);
            if (viewClass != nil) {
                [_redactClasses addObject:viewClass];
            }
        }
    }
    return self;
}

- (UIImage *)imageFromUIView:(UIView *)view
{
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES, 0);
    CGContextRef currentContext = UIGraphicsGetCurrentContext();

    [view.layer renderInContext:currentContext];

    [self maskText:view context:currentContext];

    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return screenshot;
}

- (void)maskText:(UIView *)view context:(CGContextRef)context
{
    [UIColor.blackColor setFill];
    CGPathRef maskPath = [self buildPathForView:view
                                         inPath:CGPathCreateMutable()
                                    visibleArea:view.frame];
    CGContextAddPath(context, maskPath);
    CGContextFillPath(context);
}

- (BOOL)shouldIgnoreView:(UIView *)view
{
    return [_ignoreClasses containsObject:view.class];
}

- (BOOL)shouldIgnore:(UIView *)view
{
    for (Class class in _ignoreClasses) {
        if ([view isKindOfClass:class]) {
            return true;
        }
    }
    return false;
}

- (BOOL)shouldRedact:(UIView *)view
{
    for (Class class in _redactClasses) {
        if ([view isKindOfClass:class]) {
            return true;
        }
    }

    return (
        [view isKindOfClass:UIImageView.class] && [self shouldRedactImageView:(UIImageView *)view]);
}

- (BOOL)shouldRedactImageView:(UIImageView *)imageView
{
    return imageView.image != nil &&
        [imageView.image.imageAsset valueForKey:@"_containingBundle"] == nil
        && (imageView.image.size.width > 10
            && imageView.image.size.height > 10); // This is to avoid redact gradient backgroud that
                                                  // are usually small lines repeating
}

- (CGMutablePathRef)buildPathForView:(UIView *)view
                              inPath:(CGMutablePathRef)path
                         visibleArea:(CGRect)area
{
    CGRect rectInWindow = [view convertRect:view.bounds toView:nil];

    if (!CGRectIntersectsRect(area, rectInWindow)) {
        return path;
    }

    if (view.hidden || view.alpha == 0) {
        return path;
    }

    BOOL ignore = [self shouldIgnore:view];
    if (!ignore && [self shouldRedact:view]) {
        CGPathAddRect(path, NULL, rectInWindow);
        return path;
    } else if ([self isOpaqueOrHasBackground:view]) {
        CGMutablePathRef newPath = [self excludeRect:rectInWindow fromPath:path];
        CGPathRelease(path);
        path = newPath;
    }

    if (!ignore) {
        for (UIView *subview in view.subviews) {
            path = [self buildPathForView:subview inPath:path visibleArea:area];
        }
    }

    return path;
}

- (CGMutablePathRef)excludeRect:(CGRect)rectangle fromPath:(CGMutablePathRef)path
{
    if (@available(iOS 16.0,tvOS 16.0, *)) {
        CGPathRef exclude = CGPathCreateWithRect(rectangle, nil);
        CGPathRef newPath = CGPathCreateCopyBySubtractingPath(path, exclude, YES);
        return CGPathCreateMutableCopy(newPath);
    }
    return path;
}

- (BOOL)isOpaqueOrHasBackground:(UIView *)view
{
    return view.isOpaque
        || (view.backgroundColor != nil && CGColorGetAlpha(view.backgroundColor.CGColor) > 0.9);
}

@end

NS_ASSUME_NONNULL_END
#endif // SENTRY_HAS_UIKIT
