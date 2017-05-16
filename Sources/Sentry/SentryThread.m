//
//  SentryThread.m
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryThread.h>
#import <Sentry/SentryStacktrace.h>
#else
#import "SentryThread.h"
#import "SentryStacktrace.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentryThread

- (instancetype)initWithThreadId:(NSNumber *)threadId {
    self = [super init];
    if (self) {
        self.threadId = threadId;
    }
    return self;
}

- (NSDictionary<NSString *,id> *)serialized {
    NSMutableDictionary *serializedData = @{
                                            @"id": self.threadId
                                            }.mutableCopy;
    
    [serializedData setValue:self.crashed forKey:@"crashed"];
    [serializedData setValue:self.current forKey:@"current"];
    [serializedData setValue:self.name forKey:@"name"];
    [serializedData setValue:self.reason forKey:@"reason"];
    [serializedData setValue:self.stacktrace.serialized forKey:@"stacktrace"];
    
    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
