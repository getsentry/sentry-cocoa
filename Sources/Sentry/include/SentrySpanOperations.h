#import "SentryDefines.h"
#import <Foundation/Foundation.h>

// Note: Consider adding new operations to the `SentrySpanOperation` enum in
// `SentrySpanOperations.swift` instead of adding them here.

SENTRY_EXTERN NSString *const SentrySpanOperationUILoad;
SENTRY_EXTERN NSString *const SentrySpanOperationUILoadInitialDisplay;
SENTRY_EXTERN NSString *const SentrySpanOperationUILoadFullDisplay;
SENTRY_EXTERN NSString *const SentrySpanOperationUIAction;
SENTRY_EXTERN NSString *const SentrySpanOperationUIActionClick;
