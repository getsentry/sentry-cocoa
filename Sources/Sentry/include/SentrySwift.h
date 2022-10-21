#ifndef SentrySwift_h
#define SentrySwift_h

/*
 * This is a header to expose Swift code to Objective-c
 *
 * Because we use three different package managers
 * we need to target the swift module in different ways.
 *
 * If the project is being used through SPM, Swift and Objective-c are compiled into separated
 * targets, then we use "@import SentrySwift".
 *
 * Cocoapods combines everything into one target, if the user enable USE_FRAMEWORKS,
 * Swift will be available through "#import <Sentry/Sentry-Swift.h>" otherwise "#import
 * "Sentry-Swift.h"".
 */

#if SWIFT_PACKAGE // For SWIFT PACKAGE MANAGER
@import SentrySwift;
#else
#    if __has_include(<Sentry/Sentry-Swift.h>) //COCOAPODS with USE_FRAMEWORKS
#        import <Sentry/Sentry-Swift.h>
#    else
#        import "Sentry-Swift.h" //Everything else
#    endif
#endif
#endif
