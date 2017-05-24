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

@class SentryEvent, SentryBreadcrumbStore;
@protocol SentryRequestManager;

NS_ASSUME_NONNULL_BEGIN

/**
 * `SentryClient`
 */
@interface SentryClient : NSObject

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

/*
 * Contains the last successfully sent event
 */
@property(nonatomic, strong) SentryBreadcrumbStore *breadcrumbs;


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

- (void)sendEvent:(SentryEvent *)event withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler;

- (void)    sendEvent:(SentryEvent *)event
  useClientProperties:(BOOL)useClientProperties
withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler;


/// KSCrash

/**
 * This forces a crash, useful to test the KSCrash integration
 *
 */
- (void)crash;

/**
 * This function tries to start the KSCrash handler, return YES if successfully started
 * otherwise it will return false and set error
 *
 * @param error if KSCrash is not available error will be set
 * @return successful
 */
- (BOOL)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error;


/** 
 * Report a custom, user defined exception.
 * This can be useful when dealing with scripting languages.
 *
 * If terminateProgram is true, all sentries will be uninstalled and the application will
 * terminate with an abort().
 *
 * @param name The exception name (for namespacing exception types).
 * @param reason A description of why the exception occurred.
 * @param language A unique language identifier.
 * @param lineOfCode A copy of the offending line of code (nil = ignore).
 * @param stackTrace An array of frames (dictionaries or strings) representing the call stack leading to the exception (nil = ignore).
 * @param logAllThreads If YES, suspend all threads and log their state. Note that this incurs a
 *                      performance penalty, so it's best to use only on fatal errors.
 * @param terminateProgram If YES, do not return from this function call. Terminate the program instead.
 */
- (void)reportUserException:(NSString *)name
                     reason:(NSString *)reason
                   language:(NSString *)language
                 lineOfCode:(NSString *)lineOfCode
                 stackTrace:(NSArray *)stackTrace
              logAllThreads:(BOOL)logAllThreads
           terminateProgram:(BOOL)terminateProgram;

@end

NS_ASSUME_NONNULL_END
