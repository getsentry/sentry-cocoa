#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryCoreGraphicsHelper : NSObject
+ (CGMutablePathRef)excludeRect:(CGRect)rectangle fromPath:(CGMutablePathRef)path;
@end

NS_ASSUME_NONNULL_END
