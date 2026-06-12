#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

@class SentryObjCInternalSdkApi;

NS_ASSUME_NONNULL_BEGIN

/// APIs intended for Sentry hybrid SDKs (React Native, Flutter, .NET, Unity).
///
/// These methods are public for consumption by wrapper SDKs that bridge
/// between native and managed runtimes. They may change, be renamed,
/// or be removed in any minor release without prior deprecation.
///
/// App developers: prefer the standard @c SentryObjCSDK API surface instead.
@interface SentryObjCInternalApi : NSObject
SENTRY_NO_INIT

/// SDK metadata and configuration.
@property (nonatomic, readonly) SentryObjCInternalSdkApi *sdk;

@end

NS_ASSUME_NONNULL_END
