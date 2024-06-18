#ifndef SentrySwift_h
#define SentrySwift_h

#ifdef __cplusplus
#    if __has_include(<MetricKit/MetricKit.h>)
#        import <MetricKit/MetricKit.h>
#    endif
#endif

#if __has_include("Sentry-Swift.h")
#    import "Sentry-Swift.h"
#else
#    import <Sentry/Sentry-Swift.h>
#endif

#endif
