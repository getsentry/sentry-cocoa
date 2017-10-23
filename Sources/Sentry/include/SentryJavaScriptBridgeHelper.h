//
//  SentryJavaScriptBridgeHelper.h
//  Sentry
//
//  Created by Daniel Griesser on 23.10.17.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryDefines.h>
#else
#import "SentryDefines.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryFrame, SentryEvent, SentryBreadcrumb, SentryUser;

@interface SentryJavaScriptBridgeHelper : NSObject
SENTRY_NO_INIT

+ (SentryEvent *)createSentryEventFromJavaScriptEvent:(NSDictionary *)jsonEvent;

+ (SentryBreadcrumb *)createSentryBreadcrumbFromJavaScriptBreadcrumb:(NSDictionary *)jsonBreadcrumb;

+ (NSArray *)parseJavaScriptStacktrace:(NSString *)stacktrace;

+ (NSArray *)parseRavenFrames:(NSArray *)ravenFrames;

+ (NSArray<SentryFrame *> *)convertReactNativeStacktrace:(NSArray *)stacktrace;

+ (void)addExceptionToEvent:(SentryEvent *)event type:(NSString *)type value:(NSString *)value frames:(NSArray *)frames;

+ (SentryUser *_Nullable)createUser:(NSDictionary *)user;

+ (SentrySeverity)sentrySeverityFromLevel:(NSString *)level;

+ (NSDictionary *)sanitizeDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
