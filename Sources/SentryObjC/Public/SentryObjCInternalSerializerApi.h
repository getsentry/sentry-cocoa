#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

@class SentryObjCEvent;

NS_ASSUME_NONNULL_BEGIN

/// Serialization APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalSerializerApi : NSObject
SENTRY_NO_INIT

/// Returns an event's Sentry wire-format dictionary.
- (NSDictionary<NSString *, id> *)serializeEvent:(SentryObjCEvent *)event;

@end

NS_ASSUME_NONNULL_END
