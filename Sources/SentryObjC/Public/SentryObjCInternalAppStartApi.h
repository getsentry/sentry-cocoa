#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/// App start measurement access for hybrid SDKs.
@interface SentryObjCInternalAppStartApi : NSObject
SENTRY_NO_INIT

/// When enabled, the SDK won't send the app start measurement with the first transaction.
@property (nonatomic, assign) BOOL hybridSDKMode;

/// Returns the app start measurement serialized as a dictionary with span data.
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, id> *measurementWithSpans;

@end

NS_ASSUME_NONNULL_END
