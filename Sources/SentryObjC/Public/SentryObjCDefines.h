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

#ifdef __cplusplus
#    define SENTRY_OBJC_EXTERN extern "C" __attribute__((visibility("default")))
#else
#    define SENTRY_OBJC_EXTERN extern __attribute__((visibility("default")))
#endif

#define SENTRY_NO_INIT                                                                             \
    -(instancetype)init NS_UNAVAILABLE;                                                            \
    +(instancetype) new NS_UNAVAILABLE;
