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

@protocol SentryRequestManager;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSString *const SentryClientVersionString;
SENTRY_EXTERN NSString *const SentryServerVersionString;

@interface SentryClient : NSObject

- (instancetype)initWithDsn:(NSString *)dsn
           didFailWithError:(NSError *_Nullable *_Nullable)error;

- (instancetype)initWithDsn:(NSString *)dsn
             requestManager:(id <SentryRequestManager>)requestManager
           didFailWithError:(NSError *__autoreleasing  _Nullable *)error;

+ (instancetype)sharedClient;
+ (void)setSharedClient:(SentryClient *)client;


@property(nonatomic, class, readonly, copy) NSString *versionString;
@property(nonatomic, class) SentryLogLevel logLevel;

- (BOOL)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error;

- (void)sendEventWithCompletionHandler:(_Nullable SentryQueueableRequestManagerHandler)completionHandler;

@end

NS_ASSUME_NONNULL_END
