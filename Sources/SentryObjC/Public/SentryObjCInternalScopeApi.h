#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/// Scope APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalScopeApi : NSObject
SENTRY_NO_INIT

/// Returns the current scope contexts in Sentry event wire format.
- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)serializedContexts;

@end

NS_ASSUME_NONNULL_END
