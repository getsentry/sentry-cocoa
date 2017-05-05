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
#import <Sentry/SentryLog.h>

#else
#import "SentryDefines.h"
#import "SentryLog.h"
#endif

@class SentryEvent;
@protocol SentryRequestManager;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSString *const SentryClientVersionString;
SENTRY_EXTERN NSString *const SentryServerVersionString;

/**
 * `SentryClient`
 */
@interface SentryClient : NSObject

- (instancetype)initWithDsn:(NSString *)dsn
           didFailWithError:(NSError *_Nullable *_Nullable)error;

- (instancetype)initWithDsn:(NSString *)dsn
             requestManager:(id <SentryRequestManager>)requestManager
           didFailWithError:(NSError *_Nullable *_Nullable)error;

/**
 * Returns the shared sentry client
 * @return sharedClient if it was set before
 */
+ (_Nullable instancetype)sharedClient;

/*
 * Set the shared sentry client which will be available via sharedClient
 *
 * @param client set the sharedClient to the SentryClient class
 */
+ (void)setSharedClient:(SentryClient *)client;

/**
 * This function tries to start the KSCrash handler, return YES if successfully started
 * otherwise it will return false and set error
 *
 * @param error if KSCrash is not available error will be set
 * @return successful
 */
- (BOOL)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error;

- (void)sendEventWithCompletionHandler:(_Nullable SentryRequestFinished)completionHandler;

/*
 * Return a version string e.g: 1.2.3 (3)
 */
@property(nonatomic, class, readonly, copy) NSString *versionString;
/*
 * Set logLevel for the current client default kSentryLogLevelError
 */
@property(nonatomic, class) SentryLogLevel logLevel;

/*
 * Set global tags -> these will be sent with every event
 */
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *_Nullable tags;
/*
 * Set global extra -> these will be sent with every event
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable extra;
/*
 * Contains the last successfully sent event
 */
@property(nonatomic, strong) SentryEvent *_Nullable lastEvent;
@end

NS_ASSUME_NONNULL_END
