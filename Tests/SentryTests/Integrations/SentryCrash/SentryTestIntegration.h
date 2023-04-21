#import "SentryBaseIntegration.h"
#import <Foundation/Foundation.h>

@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

@interface SentryTestIntegration : SentryBaseIntegration

@property (nonatomic, strong) SentryOptions *options;

@end

NS_ASSUME_NONNULL_END
