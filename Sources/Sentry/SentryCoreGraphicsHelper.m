#import "SentryCoreGraphicsHelper.h"
#if SENTRY_HAS_UIKIT
@implementation SentryCoreGraphicsHelper
+ (CGMutablePathRef)excludeRect:(CGRect)rectangle fromPath:(CGMutablePathRef)path
{
#    if (TARGET_OS_IOS || TARGET_OS_TV)
#        ifdef __IPHONE_16_0
    if (@available(iOS 16.0, tvOS 16.0, *)) {
        CGPathRef exclude = CGPathCreateWithRect(rectangle, nil);
        CGPathRef newPath = CGPathCreateCopyBySubtractingPath(path, exclude, YES);
        return CGPathCreateMutableCopy(newPath);
    }
#        endif // defined(__IPHONE_16_0)
#    endif // (TARGET_OS_IOS || TARGET_OS_TV)
    return path;
}
@end
#endif // SENTRY_HAS_UIKIT
