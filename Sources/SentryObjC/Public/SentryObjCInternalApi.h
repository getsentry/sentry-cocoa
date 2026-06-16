#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

@class SentryObjCInternalSdkApi;
@class SentryObjCInternalDebugApi;
@class SentryObjCInternalBreadcrumbApi;
@class SentryObjCInternalUserApi;
@class SentryObjCInternalEnvelopeApi;
#if SENTRY_OBJC_HAS_UIKIT
@class SentryObjCInternalPerformanceApi;
@class SentryObjCInternalScreenshotApi;
@class SentryObjCInternalViewHierarchyApi;
#endif

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

/// Debug image access for symbolication.
@property (nonatomic, readonly) SentryObjCInternalDebugApi *debug;

/// Breadcrumb creation from dictionary representation.
@property (nonatomic, readonly) SentryObjCInternalBreadcrumbApi *breadcrumbs;

/// User creation from dictionary representation.
@property (nonatomic, readonly) SentryObjCInternalUserApi *user;

/// Envelope store, capture, and deserialization.
@property (nonatomic, readonly) SentryObjCInternalEnvelopeApi *envelope;

#if SENTRY_OBJC_HAS_UIKIT
/// Frame tracking performance metrics.
@property (nonatomic, readonly) SentryObjCInternalPerformanceApi *performance;

/// Screenshot capture.
@property (nonatomic, readonly) SentryObjCInternalScreenshotApi *screenshot;

/// View hierarchy capture.
@property (nonatomic, readonly) SentryObjCInternalViewHierarchyApi *viewHierarchy;
#endif

@end

NS_ASSUME_NONNULL_END
