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
#else
#import "SentryEvent.h"
#import "SentryClient.h"
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
                               
    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
