#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryDefines.h>
#else
#import "SentryDefines.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryInstallation : NSObject

+ (NSString *)id;

@end

NS_ASSUME_NONNULL_END
