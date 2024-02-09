#ifndef SentrySwift_h
#define SentrySwift_h

#if SWIFT_PACKAGE
@import SentryPrivate;
#elif __has_include("Sentry-Swift.h")
#import "Sentry-Swift.h"
#else
#import "Sentry/Sentry-Swift.h"
#endif

#endif
