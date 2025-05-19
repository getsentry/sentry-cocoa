#import <Foundation/Foundation.h>

@class SentryFileManager;

@interface SentryWatchdogTerminationContextProcessor : NSObject

- (instancetype _Nonnull)initWithFileManager:(SentryFileManager *_Nonnull)fileManager;

- (void)setContext:(nullable NSDictionary<NSString *, id> *)context;

- (void)clear;

@end
