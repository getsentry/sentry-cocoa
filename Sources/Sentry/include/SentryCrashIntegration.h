//
//  SentryCrashIntegration.h
//  Sentry
//
//  Created by Klemens Mantzos on 04.12.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SentryIntegrationProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashIntegration : NSObject <SentryIntegrationProtocol>

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
 * Tells if app crashed last time it tried to launch.
 * @return BOOL
 */
- (BOOL)crashedLastLaunch;

@end

NS_ASSUME_NONNULL_END
