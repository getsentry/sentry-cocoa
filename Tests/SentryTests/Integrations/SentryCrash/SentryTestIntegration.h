#import "Sentry/SentryIntegrationProtocol.h"
#import <Foundation/Foundation.h>

@class SentryOptionsInternal;

NS_ASSUME_NONNULL_BEGIN

@interface SentryTestIntegration : NSObject <SentryIntegrationProtocol>

@property (nonatomic, strong) SentryOptionsInternal *options;

@end

NS_ASSUME_NONNULL_END
