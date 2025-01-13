#import <Foundation/Foundation.h>

// Note: Consider adding new operations to the `SentrySpanOperation` enum in
// `SentrySpanOperations.swift` instead of adding them here.

static NSString *const SentrySpanOperationUILoad = @"ui.load";
static NSString *const SentrySpanOperationUILoadInitialDisplay = @"ui.load.initial_display";
static NSString *const SentrySpanOperationUILoadFullDisplay = @"ui.load.full_display";
static NSString *const SentrySpanOperationUIAction = @"ui.action";
static NSString *const SentrySpanOperationUIActionClick = @"ui.action.click";
