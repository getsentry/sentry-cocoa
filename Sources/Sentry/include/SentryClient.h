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

/**
 * Return a version string e.g: 1.2.3 (3)
 */
@property(nonatomic, class, readonly, copy) NSString *versionString;

/**
 * Return a string sentry-cocoa
 */
@property(nonatomic, class, readonly, copy) NSString *sdkName;

@property(nonatomic, strong) SentryOptions *options;

/**
 * Initializes a SentryClient. Pass in an dictionary of options.
 *
 * @param options Options dictionary
 * @return SentryClient
 */
- (_Nullable instancetype)initWithOptions:(SentryOptions *)options;

- (void)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope;

/// SentryCrash
/// Functions below will only do something if SentryCrash is linked

@end

NS_ASSUME_NONNULL_END
