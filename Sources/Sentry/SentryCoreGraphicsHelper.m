#import "SentryCoreGraphicsHelper.h"

@implementation SentryCoreGraphicsHelper
+ (CGMutablePathRef)excludeRect:(CGRect)rectangle fromPath:(CGMutablePathRef)path
{
    if (@available(iOS 16.0, tvOS 16.0, *)) {
        CGPathRef exclude = CGPathCreateWithRect(rectangle, nil);
        CGPathRef newPath = CGPathCreateCopyBySubtractingPath(path, exclude, YES);
        return CGPathCreateMutableCopy(newPath);
    }
    return path;
}
@end
