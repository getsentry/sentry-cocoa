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

/**
 * Set logLevel for the current client default kSentryLogLevelError
 */
@property(nonatomic, class) SentryLogLevel logLevel;

@property(nonatomic, strong) SentryOptions *options;

/**
 * Defines the sample rate of SentryClient, should be a float between 0.0 and 1.0.
 */
@property(nonatomic) float sampleRate;

/**
 * This will be filled on every startup with a dictionary with extra, tags, user which will be used
 * when sending the crashreport
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable lastContext;


/**
 * Initializes a SentryClient. Pass your private DSN string.
 *
 * @param dsn DSN string of sentry
 * @param error NSError reference object
 * @return SentryClient
 */
- (_Nullable instancetype)initWithDsn:(NSString *)dsn
                     didFailWithError:(NSError *_Nullable *_Nullable)error;
    
/**
 * Initializes a SentryClient. Pass in an dictionary of options.
 *
 * @param options Options dictionary
 * @param error NSError reference object
 * @return SentryClient
 */
- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
                         didFailWithError:(NSError *_Nullable *_Nullable)error;

- (void)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope;

/// SentryCrash
/// Functions below will only do something if SentryCrash is linked

@end

NS_ASSUME_NONNULL_END
