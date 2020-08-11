//
//  SentryClient.h
//  Sentry
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentryTransport.h"

@class SentryOptions, SentrySession, SentryEvent, SentryScope, SentryThread, SentryEnvelope,
    SentryFileManager, SentryId;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Client)
@interface SentryClient : NSObject
SENTRY_NO_INIT

@property (nonatomic, strong) SentryOptions *options;

/**
 * Initializes a SentryClient. Pass in an dictionary of options.
 *
 * @param options Options dictionary
 * @return SentryClient
 */
- (_Nullable instancetype)initWithOptions:(SentryOptions *)options;

/**
 * Captures an SentryEvent.
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
- (SentryId *)captureEvent:(SentryEvent *)event
                 withScope:(SentryScope *_Nullable)scope NS_SWIFT_NAME(capture(event:scope:));

/**
 * Captures a NSError
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
- (SentryId *)captureError:(NSError *)error
                 withScope:(SentryScope *_Nullable)scope NS_SWIFT_NAME(capture(error:scope:));

/**
 * Captures a NSException
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
- (SentryId *)captureException:(NSException *)exception
                     withScope:(SentryScope *_Nullable)scope
    NS_SWIFT_NAME(capture(exception:scope:));

/**
 * Captures a Message
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
- (SentryId *)captureMessage:(NSString *)message
                   withScope:(SentryScope *_Nullable)scope NS_SWIFT_NAME(capture(message:scope:));

- (void)captureSession:(SentrySession *)session NS_SWIFT_NAME(capture(session:));

- (SentryFileManager *)fileManager;

@end

NS_ASSUME_NONNULL_END
