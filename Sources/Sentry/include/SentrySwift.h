#ifndef SentrySwift_h
#define SentrySwift_h

#if SWIFT_PACKAGE
@import SentrySwift;
#else
#    if __has_include(<Sentry/Sentry-Swift.h>)
#        import <Sentry/Sentry-Swift.h>
#    else
#        import "Sentry-Swift.h"
#    endif
#endif
#endif
