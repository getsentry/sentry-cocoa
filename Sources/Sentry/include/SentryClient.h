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

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSString *const SentryClientVersionString;
SENTRY_EXTERN NSString *const SentryServerVersionString;

@interface SentryClient : NSObject

+ (instancetype)sharedClient;

+ (void)setSharedClient:(SentryClient *)client;

- (instancetype)initWithDsn:(NSString *)dsn didFailWithError:(NSError *_Nullable *_Nullable)error;

@property(nonatomic, class, readonly, copy) NSString *versionString;
@property(nonatomic, class) SentryLogLevel logLevel;

- (bool)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
