#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentryOptions.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryInstallation : NSObject

+ (NSString *)idWithOptions:(SentryOptions *)options;

@end

NS_ASSUME_NONNULL_END
