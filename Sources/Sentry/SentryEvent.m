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
#else
#import "SentryEvent.h"
#import "SentryClient.h"
#import "SentryUser.h"
#import "SentryThread.h"
#import "SentryException.h"
#import "SentryStacktrace.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentryEvent

- (instancetype)initWithMessage:(NSString *)message timestamp:(NSDate *)timestamp level:(enum SentrySeverity)level {
    self = [super init];
    if (self) {
        self.eventId = [[NSUUID UUID].UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""];
        self.message = message;
        self.timestamp = timestamp;
        self.level = level;
        self.platform = @"cocoa";
    }
    return self;
}

- (NSString *)convertSentrySeverityToString:(SentrySeverity)severity {
    switch (severity) {
        case kSentrySeverityFatal:
            return @"fatal";
        case kSentrySeverityError:
            return @"error";
        case kSentrySeverityWarning:
            return @"warning";
        case kSentrySeverityDebug:
            return @"debug";
        default:
            return @"info";
    }
}

- (NSDictionary<NSString *, id> *)serialized {
    NSMutableDictionary *serializedData = @{
                                            @"event_id": self.eventId,
                                            @"message": self.message,
                                            @"timestamp": @((NSInteger) [self.timestamp timeIntervalSince1970]),
                                            @"level": [self convertSentrySeverityToString:self.level],
                                            @"platform": @"cocoa",
                                            }.mutableCopy;
    serializedData[@"sdk"] = @{
                               @"name": @"sentry-cocoa",
                               @"version": SentryClient.versionString
                               };
    
//    attributes.append(("contexts", Contexts().serialized))
    // Optional

    [serializedData setValue:self.logger forKey:@"logger"];
    [serializedData setValue:self.serverName forKey:@"server_name"];
    
    [serializedData setValue:self.extra forKey:@"extra"];
    [serializedData setValue:self.tags forKey:@"tags"];
    
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
    [serializedData setValue:threads forKey:@"threads"];
    
    NSMutableArray *exceptions = [NSMutableArray new];
    for (SentryThread *exception in self.exceptions) {
        [exceptions addObject:exception.serialized];
    }
    [serializedData setValue:exceptions forKey:@"exception"];
    
    NSMutableArray *debugImages = [NSMutableArray new];
    for (SentryThread *debugImage in self.debugMeta) {
        [debugImages addObject:debugImage.serialized];
    }
    [serializedData setValue:debugImages forKey:@"debug_meta"];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
