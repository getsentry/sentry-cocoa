#import "SentryDefines.h"
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
#if SENTRY_HAS_UIKIT

@interface SentryCoreGraphicsHelper : NSObject
+ (CGMutablePathRef)excludeRect:(CGRect)rectangle fromPath:(CGMutablePathRef)path;
@end

#endif
NS_ASSUME_NONNULL_END
