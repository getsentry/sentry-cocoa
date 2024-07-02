#ifndef SentrySwift_h
#define SentrySwift_h

#ifdef __cplusplus
#    if __has_include(<MetricKit/MetricKit.h>)
#        import <MetricKit/MetricKit.h>
#    endif
#endif

#ifdef SENTRY_NO_UIKIT
#    if __has_include("SentryWithoutUIKit-Swift.h")
#        import "SentryWithoutUIKit-Swift.h"
#    else
#        import <SentryWithoutUIKit/SentryWithoutUIKit-Swift.h>
#    endif
#else
#    if __has_include("Sentry-Swift.h")
#        import "Sentry-Swift.h"
#    else
#        import <Sentry/Sentry-Swift.h>
#    endif
#endif

#endif
