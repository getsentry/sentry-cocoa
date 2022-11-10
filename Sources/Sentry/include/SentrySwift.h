#ifndef SentrySwift_h
#define SentrySwift_h

/*
 * This is a header to expose Swift code to Objective-C.
 *
 * Because we use three different package managers
 * we need to target the Swift module in different ways.
 *
 * If the project is being used through SPM, Swift and Objective-C are compiled into separated
 * targets, then we use "@import SentrySwift".
 *
 * CocoaPods combines everything into one target, if the user enables USE_FRAMEWORKS,
 * Swift will be available through "#import <Sentry/Sentry-Swift.h>" otherwise "#import
 * "Sentry-Swift.h"".
 */

@import SentryPrivate;

#endif
