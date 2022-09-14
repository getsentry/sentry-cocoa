#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SentryLogOutputProtocol <NSObject>

- (void)log:(NSString *)message;

@end

@interface SentryLogOutput : NSObject <SentryLogOutputProtocol>

- (void)log:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
