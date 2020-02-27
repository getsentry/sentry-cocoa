//
//  SentryHub.h
//  Sentry
//
//  Created by Klemens Mantzos on 11.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryClient.h>
#import <Sentry/SentryScope.h>
#import <Sentry/SentryBreadcrumb.h>
#import <Sentry/SentryDefines.h>
#import <Sentry/SentryEvent.h>
#import <Sentry/SentryIntegrationProtocol.h>
#else
#import "SentryClient.h"
#import "SentryScope.h"
#import "SentryBreadcrumb.h"
#import "SentryDefines.h"
#import "SentryEvent.h"
#import "SentryIntegrationProtocol.h"
#endif

NS_ASSUME_NONNULL_BEGIN
@interface SentryHub : NSObject

/**
 * Captures an SentryEvent
 */
- (NSString *_Nullable)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope NS_SWIFT_NAME(capture(event:scope:));

/**
 * Captures a NSError
 */
- (NSString *_Nullable)captureError:(NSError *)error withScope:(SentryScope *_Nullable)scope NS_SWIFT_NAME(capture(error:scope:));

/**
 * Captures a NSException
 */
- (NSString *_Nullable)captureException:(NSException *)exception withScope:(SentryScope *_Nullable)scope NS_SWIFT_NAME(capture(exception:scope:));

/**
 * Captures a Message
 */
- (NSString *_Nullable)captureMessage:(NSString *)message withScope:(SentryScope *_Nullable)scope NS_SWIFT_NAME(capture(message:scope:));

/**
 * Invokes the callback with a mutable reference to the scope for modifications.
 */
- (void)configureScope:(void(^)(SentryScope *scope))callback;

/**
 * Adds a breadcrumb to the current scope.
 */
- (void)addBreadcrumb:(SentryBreadcrumb *)crumb;

/**
 * Returns a client if there is a bound client on the Hub.
 */
- (SentryClient *_Nullable)getClient;

/**
 * Returns a scope either the current or new.
 */
- (SentryScope *)getScope;

/**
 * Binds a different client to the hub.
 */
- (void)bindClient:(SentryClient *_Nullable)client;

/**
 * Checks if integration is activated for bound client and returns it.
 */
- (id _Nullable)getIntegration:(NSString *)integrationName;

@end

NS_ASSUME_NONNULL_END
