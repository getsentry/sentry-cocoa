//
//  SentryException.m
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryException.h>
#import <Sentry/SentryThread.h>
#import <Sentry/SentryStacktrace.h>
#else
#import "SentryException.h"
#import "SentryThread.h"
#import "SentryStacktrace.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentryException

- (instancetype)initWithValue:(NSString *)value type:(NSString *)type {
    self = [super init];
    if (self) {
        self.value = value;
        self.type = type;
    }
    return self;
}

- (NSDictionary<NSString *,id> *)serialized {
    NSMutableDictionary *serializedData = @{
                                            @"value": self.value,
                                            @"type": self.type
                                            }.mutableCopy;
    
    [serializedData setValue:self.mechanism forKey:@"mechanism"];
    [serializedData setValue:self.module forKey:@"module"];
    [serializedData setValue:self.thread.threadId forKey:@"thread_id"];
    [serializedData setValue:self.thread.stacktrace.serialized forKey:@"stacktrace"];
    
    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
