#import <Foundation/Foundation.h>
#import "SentryLogSink.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryLogSinkPrintf : NSObject <SentryLogSink>

- (void)log:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
