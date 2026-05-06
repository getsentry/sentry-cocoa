#import <Foundation/Foundation.h>

#ifndef TARGET_OS_VISION
#    define TARGET_OS_VISION 0
#endif

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
#    define SENTRY_OBJC_UIKIT_AVAILABLE 1
#else
#    define SENTRY_OBJC_UIKIT_AVAILABLE 0
#endif

#if SENTRY_OBJC_UIKIT_AVAILABLE && !SENTRY_NO_UI_FRAMEWORK
#    define SENTRY_OBJC_HAS_UIKIT 1
#else
#    define SENTRY_OBJC_HAS_UIKIT 0
#endif

#if SENTRY_OBJC_HAS_UIKIT && !TARGET_OS_VISION
#    define SENTRY_OBJC_REPLAY_SUPPORTED 1
#else
#    define SENTRY_OBJC_REPLAY_SUPPORTED 0
#endif

// Macros required by re-exported main SDK headers (SentryBreadcrumb.h,
// SentryEvent.h, SentryScope.h, etc.). When those headers fall through
// their __has_include chain they pick up *this* SentryObjCDefines.h, so
// every macro they reference must be present here.
#ifndef SENTRY_HEADER
#    if __has_include(<SentryObjC/SentryObjC.h>)
#        define SENTRY_HEADER(file) <SentryObjC/file.h>
#    else
#        define SENTRY_HEADER(file) <file.h>
#    endif
#endif

#ifdef __cplusplus
#    define SENTRY_OBJC_EXTERN extern "C" __attribute__((visibility("default")))
#else
#    define SENTRY_OBJC_EXTERN extern __attribute__((visibility("default")))
#endif

#ifndef SENTRY_EXTERN
#    define SENTRY_EXTERN SENTRY_OBJC_EXTERN
#endif

#ifndef SENTRY_HAS_UIKIT
#    define SENTRY_HAS_UIKIT SENTRY_OBJC_HAS_UIKIT
#endif

#ifndef SENTRY_UIKIT_AVAILABLE
#    define SENTRY_UIKIT_AVAILABLE SENTRY_OBJC_UIKIT_AVAILABLE
#endif

#ifndef SENTRY_TARGET_REPLAY_SUPPORTED
#    define SENTRY_TARGET_REPLAY_SUPPORTED SENTRY_OBJC_REPLAY_SUPPORTED
#endif

#define SENTRY_NO_INIT                                                                             \
    -(instancetype)init NS_UNAVAILABLE;                                                            \
    +(instancetype) new NS_UNAVAILABLE;

#import "SentryLog.h"

@class SentryBreadcrumb;
@class SentryEvent;
@class SentryObjCMetric;
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
typedef SentryObjCMetric *_Nullable (^SentryBeforeSendMetricCallback)(
    SentryObjCMetric *_Nonnull metric);

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
 * @see SentryObjcSDK For the main SDK entry point.
 * @see SentryOptions For configuration options.
 */

NS_ASSUME_NONNULL_END
