#import <Foundation/Foundation.h>

#ifndef TARGET_OS_VISION
#    define TARGET_OS_VISION 0
#endif

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
#    define SENTRY_OBJC_UIKIT_AVAILABLE 1
#else
#    define SENTRY_OBJC_UIKIT_AVAILABLE 0
#endif

#if SENTRY_OBJC_UIKIT_AVAILABLE && !TARGET_OS_VISION
#    define SENTRY_OBJC_REPLAY_SUPPORTED 1
#else
#    define SENTRY_OBJC_REPLAY_SUPPORTED 0
#endif

@class SentryBreadcrumb;
@class SentryEvent;
@class SentryLog;
@class SentrySamplingContext;
@protocol SentrySpan;

NS_ASSUME_NONNULL_BEGIN

typedef SentryBreadcrumb *_Nullable (^SentryBeforeBreadcrumbCallback)(
    SentryBreadcrumb *_Nonnull breadcrumb);
typedef SentryEvent *_Nullable (^SentryBeforeSendEventCallback)(SentryEvent *_Nonnull event);
typedef id<SentrySpan> _Nullable (^SentryBeforeSendSpanCallback)(id<SentrySpan> _Nonnull span);
typedef SentryLog *_Nullable (^SentryBeforeSendLogCallback)(SentryLog *_Nonnull log);
typedef BOOL (^SentryBeforeCaptureScreenshotCallback)(SentryEvent *_Nonnull event);
typedef void (^SentryOnCrashedLastRunCallback)(SentryEvent *_Nonnull event);
typedef NSNumber *_Nullable (^SentryTracesSamplerCallback)(
    SentrySamplingContext *_Nonnull samplingContext);

#ifdef __cplusplus
#    define SENTRY_OBJC_EXTERN extern "C" __attribute__((visibility("default")))
#else
#    define SENTRY_OBJC_EXTERN extern __attribute__((visibility("default")))
#endif

#define SENTRY_NO_INIT                                                                             \
    -(instancetype)init NS_UNAVAILABLE;                                                            \
    +(instancetype) new NS_UNAVAILABLE;

/**
 * SentryObjC — Pure Objective-C wrapper for the Sentry SDK.
 *
 * This module provides a self-contained public interface usable from Objective-C
 * and Objective-C++ without requiring Clang modules (-fmodules). Use this when
 * integrating Sentry into projects that cannot enable modules (e.g. React Native,
 * Haxe, custom build systems).
 *
 * @discussion Import the umbrella header:
 * @code
 * #import "SentryObjC.h"
 * @endcode
 *
 * @see SentrySDK For the main SDK entry point.
 * @see SentryOptions For configuration options.
 */

NS_ASSUME_NONNULL_END
