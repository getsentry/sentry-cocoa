//
//  SentryClient.h
//  Sentry
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryDefines.h>
#import <Sentry/SentryOptions.h>
#import <Sentry/SentryScope.h>
#import <Sentry/SentryTransport.h>

#else
#import "SentryDefines.h"
#import "SentryOptions.h"
#import "SentryScope.h"
#import "SentryTransport.h"
#endif

@class SentryEvent, SentryThread;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Client)
@interface SentryClient : NSObject
SENTRY_NO_INIT

@property(nonatomic, strong) SentryOptions *options;

/**
 * Initializes a SentryClient. Pass in an dictionary of options.
 *
 * @param options Options dictionary
 * @return SentryClient
 */
- (_Nullable instancetype)initWithOptions:(SentryOptions *)options;

/**
 * Captures an SentryEvent
 */
- (void)captureEvent:(SentryEvent *)event withScopes:(NSArray<SentryScope *>*_Nullable)scopes NS_SWIFT_NAME(capture(event:scopes:));

/**
 * Captures a NSError
 */
- (void)captureError:(NSError *)error withScopes:(NSArray<SentryScope *>*_Nullable)scopes NS_SWIFT_NAME(capture(error:scopes:));

/**
 * Captures a NSException
 */
- (void)captureException:(NSException *)exception withScopes:(NSArray<SentryScope *>*_Nullable)scopes NS_SWIFT_NAME(capture(exception:scopes:));

/**
* Captures a Message
*/
- (void)captureMessage:(NSString *)message withScopes:(NSArray<SentryScope *>*_Nullable)scopes NS_SWIFT_NAME(capture(message:scopes:));

@end

NS_ASSUME_NONNULL_END
