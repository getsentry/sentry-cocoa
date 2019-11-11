//
//  Sentry.h
//  Sentry
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for Sentry.
FOUNDATION_EXPORT double SentryVersionNumber;

//! Project version string for Sentry.
FOUNDATION_EXPORT const unsigned char SentryVersionString[];

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryCrash.h>
#import <Sentry/SentryClient.h>
#import <Sentry/SentrySwizzle.h>

#import <Sentry/SentryNSURLRequest.h>

#import <Sentry/SentrySerializable.h>

#import <Sentry/SentryEvent.h>
#import <Sentry/SentryThread.h>
#import <Sentry/SentryMechanism.h>
#import <Sentry/SentryException.h>
#import <Sentry/SentryStacktrace.h>
#import <Sentry/SentryFrame.h>
#import <Sentry/SentryUser.h>
#import <Sentry/SentryDebugMeta.h>
#import <Sentry/SentryContext.h>
#import <Sentry/SentryBreadcrumb.h>
#import <Sentry/SentryBreadcrumbStore.h>

#import <Sentry/SentryJavaScriptBridgeHelper.h>

#else

#import "SentryCrash.h"
#import "SentryClient.h"
#import "SentrySwizzle.h"

#import "SentryNSURLRequest.h"

#import "SentrySerializable.h"

#import "SentryEvent.h"
#import "SentryThread.h"
#import "SentryMechanism.h"
#import "SentryException.h"
#import "SentryStacktrace.h"
#import "SentryFrame.h"
#import "SentryUser.h"
#import "SentryDebugMeta.h"
#import "SentryContext.h"
#import "SentryBreadcrumb.h"
#import "SentryBreadcrumbStore.h"

#import "SentryJavaScriptBridgeHelper.h"

#endif

@interface Sentry : NSObject
SENTRY_NO_INIT


//- `init(options)`: This is the entry point for every SDK.
//
//    This typically creates / reinitializes the global hub which is propagated to all new threads/execution contexts, or a hub is created per thread/execution context.
//
//    Takes options (dsn etc.), configures a client and binds it to the current hub or initializes it. Should return a stand-in that can be used to drain events (a disposable).
//
//    This might return a handle or guard for disposing. How this is implemented is entirely up to the SDK. This might even be a client if that’s something that makes sense for the SDK. In Rust it’s a ClientInitGuard, in JavaScript it could be a helper object with a close method that is awaitable.
//
//    You should be able to call this multiple times where calling it a second time either tears down the previous client or decrements a refcount for the previous client etc.
//
//    Calling this multiple times should be used for testing only.
//    It’s undefined what happens if you call `init` on anything but application startup.
//
//    A user has to call `init` once but it’s permissible to call this with a disabled DSN of sorts. Might for instance be no parameter passed etc.
//
//    Additionally it also setups all default integrations.

+ (void)initWithDsn:(NSString *)dsn;
+ (void)initWithOptions:(NSDictionary<NSString *, id> *)options;

//- `capture_event(event)`: Takes an already assembled event and dispatches it to the currently active hub. The event object can be a plain dictionary or a typed object whatever makes more sense in the SDK. It should follow the native protocol as close as possible ignoring platform specific renames (case styles etc.).

+ (void)captureEvent:(SentryEvent *)event;

//- `capture_exception(error)`: Report an error or exception object. Depending on the platform different parameters are possible. The most obvious version accepts just an error object but also variations are possible where no error is passed and the current exception is used. The client should convert the passed argument to a valid Sentry event.

+ (void)captureError:(NSError *)error;
+ (void)captureException:(NSException *)exception;


//- `capture_message(message, level)`: Reports a message. The level can be optional in language with default parameters in which case it should default to `info`.

+ (void)captureMessage:(NSString *)message;

//- `add_breadcrumb(crumb)`: Adds a new breadcrumb to the scope. If the total number of breadcrumbs exceeds the `max_breadcrumbs` setting, the oldest breadcrumb should be removed in turn. This works like the Hub api with regards to what `crumb` can be.

+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb;

//- `configure_scope(callback)`: Calls a callback with a scope object that can be reconfigured. This is used to attach contextual data for future events in the same scope.

// TODO(fetzig): requires scope that is detached from SentryClient.finish this as soon as SentryScope has been implemented.
//+ (void)configureScope:(void(^)(int))callback;
@end
