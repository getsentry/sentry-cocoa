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
#import <Sentry/SentrySerializable.h>
#else
#import "SentryDefines.h"
#import "SentrySerializable.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryThread, SentryException, SentryStacktrace, SentryUser, SentryDebugMeta, SentryContext;

@interface SentryEvent : NSObject <SentrySerializable>

@property(nonatomic, copy) NSString *eventId;
@property(nonatomic, copy) NSString *message;
@property(nonatomic, strong) NSDate *timestamp;
@property(nonatomic) enum SentrySeverity level;
@property(nonatomic, copy) NSString *platform;

@property(nonatomic, copy) NSString *_Nullable logger;
@property(nonatomic, copy) NSString *_Nullable serverName;
@property(nonatomic, copy) NSString *_Nullable releaseName;
@property(nonatomic, copy) NSString *_Nullable dist;
@property(nonatomic, copy) NSString *_Nullable environment;

@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *_Nullable tags;
@property(nonatomic, strong) NSDictionary<NSString *, id <NSSecureCoding>> *_Nullable extra;
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *_Nullable modules;

@property(nonatomic, strong) NSArray<NSString *> *_Nullable fingerprint;
@property(nonatomic, strong) SentryUser *_Nullable user;
@property(nonatomic, strong) SentryContext *_Nullable context;
@property(nonatomic, strong) NSArray<SentryThread *> *_Nullable threads;
@property(nonatomic, strong) NSArray<SentryException *> *_Nullable exceptions;
@property(nonatomic, strong) SentryStacktrace *_Nullable stacktrace;
@property(nonatomic, strong) NSArray<SentryDebugMeta *> *_Nullable debugMeta;

@property(nonatomic, strong) NSDictionary<NSString *, id <NSSecureCoding>> *_Nullable breadcrumbsSerialized;

/**
 * This property is there for setting main bundle of the app
 */
@property(nonatomic, strong) NSDictionary *infoDict;

- (instancetype)initWithLevel:(enum SentrySeverity)level;

@end

NS_ASSUME_NONNULL_END
