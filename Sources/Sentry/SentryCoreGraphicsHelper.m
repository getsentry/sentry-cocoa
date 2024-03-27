#import "SentryCoreGraphicsHelper.h"
#if SENTRY_HAS_UIKIT
@implementation SentryCoreGraphicsHelper
+ (CGMutablePathRef)excludeRect:(CGRect)rectangle fromPath:(CGMutablePathRef)path
{
#    if (TARGET_OS_IOS && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_16_0)                        \
        || (TARGET_OS_TV && __TV_OS_VERSION_MAX_ALLOWED >= __TVOS_16_0)
    if (@available(iOS 16.0, tvOS 16.0, *)) {
        CGPathRef exclude = CGPathCreateWithRect(rectangle, nil);
        CGPathRef newPath = CGPathCreateCopyBySubtractingPath(path, exclude, YES);
        return CGPathCreateMutableCopy(newPath);
    }
#    endif
    return path;
}
@end
#endif
