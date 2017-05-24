//
//  SentryEvent.m
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryEvent.h>
#import <Sentry/SentryClient.h>
#import <Sentry/SentryUser.h>
#import <Sentry/SentryThread.h>
#import <Sentry/SentryException.h>
#import <Sentry/SentryStacktrace.h>
#import <Sentry/SentryContext.h>
#import <Sentry/NSDate+Extras.h>
#else
#import "SentryEvent.h"
#import "SentryClient.h"
#import "SentryUser.h"
#import "SentryThread.h"
#import "SentryException.h"
#import "SentryStacktrace.h"
#import "SentryContext.h"
#import "NSDate+Extras.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentryEvent

- (instancetype)initWithLevel:(enum SentrySeverity)level {
    self = [super init];
    if (self) {
        self.eventId = [[NSUUID UUID].UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""];
        self.level = level;
        self.platform = @"cocoa";
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialized {
    if (nil == self.timestamp) {
        self.timestamp = [NSDate date];
    }
    NSMutableDictionary *serializedData = @{
                                            @"event_id": self.eventId,
                                            @"timestamp": [self.timestamp toIso8601String],
                                            @"level": SentrySeverityNames[self.level],
                                            @"platform": @"cocoa",
                                            }.mutableCopy;
    serializedData[@"sdk"] = @{
                               @"name": @"sentry-cocoa",
                               @"version": SentryClient.versionString
                               };

    if (nil == self.context) {
        self.context = [SentryContext new];
    }
    [serializedData setValue:self.context.serialized forKey:@"contexts"];
    
    [serializedData setValue:self.message forKey:@"message"];
    [serializedData setValue:self.logger forKey:@"logger"];
    [serializedData setValue:self.serverName forKey:@"server_name"];
    
    [serializedData setValue:self.extra forKey:@"extra"];
    [serializedData setValue:self.tags forKey:@"tags"];
    
    if (nil == self.releaseName || nil == self.dist) {
        NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
        if (nil == self.releaseName) {
            self.releaseName = [NSString stringWithFormat:@"%@-%@", infoDict[@"CFBundleIdentifier"], infoDict[@"CFBundleShortVersionString"]];
        }
        if (nil == self.dist) {
            self.dist = infoDict[@"CFBundleVersion"];
        }
        
        // If we run tests self.dist is nil we also sent releaseName to nil since we don't ever
        // want a (null)-(null) release
        if (nil == self.dist) {
            self.releaseName = nil;
        }
    }
    [serializedData setValue:self.releaseName forKey:@"release"];
    [serializedData setValue:self.dist forKey:@"dist"];
    
    [serializedData setValue:self.fingerprint forKey:@"fingerprint"];
    
    [serializedData setValue:self.user.serialized forKey:@"user"];
    [serializedData setValue:self.modules forKey:@"modules"];
    
    [serializedData setValue:self.stacktrace.serialized forKey:@"stacktrace"];
    
    NSMutableArray *threads = [NSMutableArray new];
    for (SentryThread *thread in self.threads) {
        [threads addObject:thread.serialized];
    }
    if (threads.count > 0) {
        [serializedData setValue:@{@"values": threads} forKey:@"threads"];
    }
    
    NSMutableArray *exceptions = [NSMutableArray new];
    for (SentryThread *exception in self.exceptions) {
        [exceptions addObject:exception.serialized];
    }
    if (exceptions.count > 0) {
        [serializedData setValue:@{@"values": exceptions} forKey:@"exception"];
    }
    
    NSMutableArray *debugImages = [NSMutableArray new];
    for (SentryThread *debugImage in self.debugMeta) {
        [debugImages addObject:debugImage.serialized];
    }
    if (debugImages.count > 0) {
        [serializedData setValue:@{@"images": debugImages} forKey:@"debug_meta"];
    }

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
