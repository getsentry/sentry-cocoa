#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryObjCScope;

/// Scope APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalScopeApi : NSObject
SENTRY_NO_INIT

/// Returns the current scope contexts in Sentry event wire format.
- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)serializedContexts;

/// Sets the given scope as the current scope for the duration of the callback.
- (void)withCurrentScope:(SentryObjCScope *)scope callback:(void(NS_NOESCAPE ^)(void))callback;

/// Creates a new empty scope.
- (SentryObjCScope *)createScope;

/// Creates a deep copy of the given scope.
- (SentryObjCScope *)cloneScope:(SentryObjCScope *)scope;

@end

NS_ASSUME_NONNULL_END
