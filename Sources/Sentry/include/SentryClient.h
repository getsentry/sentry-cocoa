//
//  SentryClient.h
//  Sentry
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentryOptions.h"
#import "SentryScope.h"
#import "SentryTransport.h"

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
 * sends event
 */
- (void)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope;

/// SentryCrash
/// Functions below will only do something if SentryCrash is linked

@end

NS_ASSUME_NONNULL_END
