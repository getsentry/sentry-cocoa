#import <Foundation/Foundation.h>
#import "SentryLogSink.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryLogSinkNSLog : NSObject <SentryLogSink>

- (void)log:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
