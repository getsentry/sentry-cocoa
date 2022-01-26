#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryIntegrationProvider : NSObject

@property (nonatomic, strong, readonly) NSArray<NSString *> *enabledIntegrations;

@end

NS_ASSUME_NONNULL_END
