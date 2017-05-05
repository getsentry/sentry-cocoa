//
//  SentryEvent.h
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryDefines.h>
#else
#import "SentryDefines.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryThread, SentryException, SentryStacktrace, SentryUser;

@interface SentryEvent : NSObject

@property(nonatomic, copy) NSString *eventID;
@property(nonatomic, copy) NSString *message;
@property(nonatomic, strong) NSDate *timestamp;
@property(nonatomic) enum SentrySeverity level;
@property(nonatomic, copy) NSString *platform;
@property(nonatomic, copy) NSString *_Nullable logger;
@property(nonatomic, copy) NSString *_Nullable culprit;
@property(nonatomic, copy) NSString *_Nullable serverName;
@property(nonatomic, copy) NSString *_Nullable releaseVersion;
@property(nonatomic, copy) NSString *_Nullable buildNumber;
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *_Nullable tags;
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable extra;
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *_Nullable modules;
@property(nonatomic, copy) NSArray<NSString *> *_Nullable fingerprint;
@property(nonatomic, strong) SentryUser *_Nullable user;
@property(nonatomic, copy) NSArray<SentryThread *> *_Nullable threads;
@property(nonatomic, copy) NSArray<SentryException *> *_Nullable exceptions;
@property(nonatomic, strong) SentryStacktrace *_Nullable stacktrace;
@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *_Nullable breadcrumbsSerialized;

//- (nonnull instancetype)init:(NSString *_Nonnull)message
//                     eventID:(NSString *_Nullable)eventID
//                   timestamp:(NSDate *_Nonnull)timestamp
//                       level:(enum SentrySeverity)level
//                      logger:(NSString *_Nullable)logger
//                     culprit:(NSString *_Nullable)culprit
//                  serverName:(NSString *_Nullable)serverName
//                     release:(NSString *_Nullable)release
//                 buildNumber:(NSString *_Nullable)buildNumber
//                        tags:(NSDictionary<NSString *, NSString *> *_Nonnull)tags
//                     modules:(NSDictionary<NSString *, NSString *> *_Nullable)modules
//                       extra:(NSDictionary<NSString *, id> *_Nonnull)extra
//                 fingerprint:(NSArray<NSString *> *_Nullable)fingerprint
//                        user:(SentryUser *_Nullable)user
//                  exceptions:(NSArray<SentryException *> *_Nullable)exceptions
//                  stacktrace:(SentryStacktrace *_Nullable)stacktrace;
//
//- (instancetype)initWithEventID:(NSString *)eventID;
//
//- (instancetype)initWithEventID:(NSString *)eventID message:(NSString *)message timestamp:(NSDate *)timestamp
//                          level:(enum SentrySeverity)level platform:(NSString *)platform logger:(NSString *)logger
//                        culprit:(NSString *)culprit serverName:(NSString *)serverName
//                 releaseVersion:(NSString *)releaseVersion buildNumber:(NSString *)buildNumber
//                           tags:(NSDictionary<NSString *, NSString *> *)tags
//                        modules:(NSDictionary<NSString *, NSString *> *)modules extra:(NSDictionary<NSString *> *)extra
//                    fingerprint:(NSArray<NSString *> *)fingerprint user:(SentryUser *)user
//                        threads:(NSArray<SentryThread *> *)threads exceptions:(NSArray<SentryException *> *)exceptions
//                     stacktrace:(SentryStacktrace *)stacktrace
//          breadcrumbsSerialized:(NSArray<NSDictionary<NSString *> *> *)breadcrumbsSerialized;
//
//
//+ (instancetype)eventWithEventID:(NSString *)eventID;

@end

NS_ASSUME_NONNULL_END
