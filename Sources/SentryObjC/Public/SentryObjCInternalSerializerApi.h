#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

@class SentryObjCEvent;
@class SentryObjCScope;
@class SentryObjCDebugMeta;

NS_ASSUME_NONNULL_BEGIN

/// Serialization APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalSerializerApi : NSObject
SENTRY_NO_INIT

/// Returns a scope's dictionary, including the singular @c context key used by hybrid SDKs.
- (NSDictionary<NSString *, id> *)serializeScope:(SentryObjCScope *)scope;

/// Returns a debug image's Sentry wire-format dictionary.
- (NSDictionary<NSString *, id> *)serializeDebugMeta:(SentryObjCDebugMeta *)debugMeta;

/// Returns an event's Sentry wire-format dictionary.
- (NSDictionary<NSString *, id> *)serializeEvent:(SentryObjCEvent *)event;

@end

NS_ASSUME_NONNULL_END
