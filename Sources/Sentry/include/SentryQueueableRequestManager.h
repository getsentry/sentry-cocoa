#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryDefines.h>
#import <Sentry/SentryRequestManager.h>

#else
#import "SentryDefines.h"
#import "SentryRequestManager.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryQueueableRequestManager : NSObject <SentryRequestManager>

@end

NS_ASSUME_NONNULL_END
