//
//  SentryEvent.h
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SentryThread, SentryException, SentryStacktrace, SentryUser;

@interface SentryEvent : NSObject

@property (nonatomic, copy) NSString * _Nonnull eventID;
@property (nonatomic, copy) NSString * _Nonnull message;
@property (nonatomic, strong) NSDate * _Nonnull timestamp;
@property (nonatomic) enum SentrySeverity level;
@property (nonatomic, copy) NSString * _Nonnull platform;
@property (nonatomic, copy) NSString * _Nullable logger;
@property (nonatomic, copy) NSString * _Nullable culprit;
@property (nonatomic, copy) NSString * _Nullable serverName;
@property (nonatomic, copy) NSString * _Nullable releaseVersion;
@property (nonatomic, copy) NSString * _Nullable buildNumber;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> * _Nonnull tags;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> * _Nullable modules;
@property (nonatomic, copy) NSDictionary<NSString *, id> * _Nonnull extra;
@property (nonatomic, copy) NSArray<NSString *> * _Nullable fingerprint;
@property (nonatomic, strong) SentryUser * _Nullable user;
@property (nonatomic, copy) NSArray<SentryThread *> * _Nullable threads;
@property (nonatomic, copy) NSArray<SentryException *> * _Nullable exceptions;
@property (nonatomic, strong) SentryStacktrace * _Nullable stacktrace;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> * _Nullable breadcrumbsSerialized;

- (nonnull instancetype)init:(NSString * _Nonnull)message
                     eventID:(NSString * _Nullable)eventID
                   timestamp:(NSDate * _Nonnull)timestamp
                       level:(enum SentrySeverity)level
                      logger:(NSString * _Nullable)logger
                     culprit:(NSString * _Nullable)culprit
                  serverName:(NSString * _Nullable)serverName
                     release:(NSString * _Nullable)release
                 buildNumber:(NSString * _Nullable)buildNumber
                        tags:(NSDictionary<NSString *, NSString *> * _Nonnull)tags
                     modules:(NSDictionary<NSString *, NSString *> * _Nullable)modules
                       extra:(NSDictionary<NSString *, id> * _Nonnull)extra
                 fingerprint:(NSArray<NSString *> * _Nullable)fingerprint
                        user:(SentryUser * _Nullable)user
                  exceptions:(NSArray<SentryException *> * _Nullable)exceptions
                  stacktrace:(SentryStacktrace * _Nullable)stacktrace;


@end
