//
//  SentryClient.h
//  Sentry
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Sentry/SentryDefines.h>
#import <Sentry/SentryLog.h>

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSString *const SentryClientVersionString;
SENTRY_EXTERN NSString *const SentryServerVersionString;

@interface SentryClient : NSObject

+ (instancetype)sharedClient;

+ (void)setSharedClient:(SentryClient *)client;

- (instancetype)initWithDsn:(NSString *)dsn didFailWithError:(NSError *_Nullable *_Nullable)error;

@property(nonatomic, class, readonly, copy) NSString *versionString;
@property(nonatomic, class) SentryLogLevel logLevel;

#if __has_include(<KSCrash/KSCrash.h>)
- (void)startCrashHandler;
#endif

@end

NS_ASSUME_NONNULL_END
