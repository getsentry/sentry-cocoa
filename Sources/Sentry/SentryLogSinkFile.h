#import "SentryLogSink.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryLogSinkFile : NSObject <SentryLogSink>

- (void)log:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
