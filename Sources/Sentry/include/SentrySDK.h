//
//  SentrySDK.h
//  Sentry
//
//  Created by Klemens Mantzos on 12.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryDefines.h>
#import <Sentry/SentryHub.h>
#import <Sentry/SentryEvent.h>
#import <Sentry/SentryBreadcrumb.h>
#import <Sentry/SentryOptions.h>
#else
#import "SentryDefines.h"
#import "SentryHub.h"
#import "SentryEvent.h"
#import "SentryBreadcrumb.h"
#import "SentryOptions.h"
#endif

NS_ASSUME_NONNULL_BEGIN

//NS_SWIFT_NAME(SDK)
/**
 "static api" for easy access to most common sentry sdk features
 
 try `SentryHub` for advanced features
 */
@interface SentrySDK : NSObject
SENTRY_NO_INIT


/**
 returns current hub
 */
+ (SentryHub *)currentHub;

/**
 * This forces a crash, useful to test the SentryCrash integration
 */
+ (void)crash;

/**
 sets current hub
 */
+ (void)setCurrentHub:(SentryHub *)hub;

/**
 entry point of static API

 adds options to hub/client and starts error monitoring.
 */
+ (void)startWithOptions:(SentryOptions *)options NS_SWIFT_NAME(start(options:));

/**
 starts sentry with options and starts crash handler
 
 Inits and configures Sentry (SentryHub, SentryClient) and starts crash handler
 */
+ (void)startWithOptionsDict:(NSDictionary<NSString *, id> *)optionsDict NS_SWIFT_NAME(start(options:));

/**
 captures an event aka. sends an event to sentry

 uses default `SentryHub`
 
 USAGE: Create a `SentryEvent`, fill it up with data, and send it with this method.
 */
+ (void)captureEvent:(SentryEvent *)event NS_SWIFT_NAME(capture(event:));

/**
 captures an error aka. sends an NSError to sentry.
 
 uses default `SentryHub`
 */
+ (void)captureError:(NSError *)error NS_SWIFT_NAME(capture(error:));

/**
 captures an exception aka. sends an NSException to sentry.
 
 uses default `SentryHub`
 */
+ (void)captureException:(NSException *)exception NS_SWIFT_NAME(capture(exception:));

/**
 captures a message aka. sends a string to sentry.
 
 uses default `SentryHub`
 */
+ (void)captureMessage:(NSString *)message NS_SWIFT_NAME(capture(message:));

/**
 adds a SentryBreadcrumb to the SentryClient.
 
 If the total number of breadcrumbs exceeds the `max_breadcrumbs` setting, the oldest breadcrumb is removed in turn.
 
 uses default `SentryHub`
 
 TODO(fetzig): As soon as `SentryScope` handles the scope and `SentryClient` is stateless, `crumb` will be added to `SentryScope`.
 */
+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb NS_SWIFT_NAME(add(crumb:));

// TODO(fetzig): configureScope() requires a `SentryScope` that is detached from SentryClient. Add this method as soon as SentryScope has been implemented.
//- `configure_scope(callback)`: Calls a callback with a scope object that can be reconfigured. This is used to attach contextual data for future events in the same scope.
+ (void)configureScope:(void(^)(SentryScope *scope))callback;

@end

NS_ASSUME_NONNULL_END
