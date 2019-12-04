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

/**
 * This function tries to start the SentryCrash handler, return YES if successfully started
 * otherwise it will return false and set error
 *
 * @param error if SentryCrash is not available error will be set
 * @return successful
 */
- (BOOL)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error;

/**
 * Report a custom, user defined exception. Only works if SentryCrash is linked.
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

/**
 * Returns true if the app crashed before launching now
 */
- (BOOL)crashedLastLaunch;

/**
 * This will snapshot the whole stacktrace at the time when its called. This stacktrace will be attached with the next sent event.
 * Please note to also call appendStacktraceToEvent in the callback in order to send the stacktrace with the event.
 */
- (void)snapshotStacktrace:(void (^)(void))snapshotCompleted;

/**
 * This appends the stored stacktrace (if existant) to the event.
 *
 * @param event SentryEvent event
 */
- (void)appendStacktraceToEvent:(SentryEvent *)event;

@end

NS_ASSUME_NONNULL_END
