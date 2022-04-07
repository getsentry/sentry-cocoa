#import "SentryDiscardReason.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryDiscardReasonMapper : NSObject

+ (SentryDiscardReason)mapStringToReason:(NSString *)value;

@end

NS_ASSUME_NONNULL_END
