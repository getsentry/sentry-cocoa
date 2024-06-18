#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SentryLogSink <NSObject>

- (void)log:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
