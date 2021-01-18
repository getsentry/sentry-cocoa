//
//  SentryTransaction.m
//  Sentry
//
//  Created by Dhiogo Brustolin on 11/01/21.
//  Copyright © 2021 Sentry. All rights reserved.
//

#import "SentryTransaction.h"
#import "NSDate+SentryExtras.h"
#import "NSDictionary+SentrySanitize.h"
#import "SentryCurrentDate.h"
#import "SentryId.h"
#import "SentryHub.h"
#import "SentrySpanContext.h"
#import "SentrySpanId.h"
#import "SentryTransactionContext.h"


@interface SentryTransaction () {
    SentrySpanContext* trace;
}

@end

@implementation SentryTransaction


- (NSDictionary<NSString *, id> *)serialize
{
    if (nil == self.timestamp) {
        self.timestamp = [SentryCurrentDate date];
    }
    
    NSMutableDictionary *serializedData = @{
        @"event_id" : self.eventId.sentryIdString,
        @"timestamp" : [self.timestamp sentry_toIso8601String],
        @"spans": @[],
        @"type":@"transaction"
    }
    .mutableCopy;
    
    [self addSimpleProperties:serializedData];
    
    // This is important here, since we probably use __sentry internal extras
    // before
    [serializedData setValue:self.tags forKey:@"tags"];
    
    return serializedData;
}

- (void)addSimpleProperties:(NSMutableDictionary *)serializedData
{
    [serializedData setValue:self.sdk forKey:@"sdk"];
    [serializedData setValue:self.transaction forKey:@"transaction"];

    
    NSMutableDictionary* mutableContext = [[NSMutableDictionary alloc] init];
    mutableContext[@"trace"] = @{
        @"name": self.transaction,
        @"span_id": trace.spanId.sentrySpanIdString,
        @"tags":@{},
        @"trace_id": [[SentryId alloc] init].sentryIdString
    };
    
    if (self.context != nil) {
        [mutableContext addEntriesFromDictionary:self.context];
    }
    
    [serializedData setValue:mutableContext forKey:@"contexts"];

    if (nil != self.startTimestamp) {
        [serializedData setValue:[self.startTimestamp sentry_toIso8601String]
                          forKey:@"start_timestamp"];
    } else {
        // start timestamp should never be empty
        [serializedData setValue:[self.timestamp sentry_toIso8601String]
                          forKey:@"start_timestamp"];
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.eventId = [[SentryId alloc] init];
    }
    return self;
}

/*-(instancetype)initWithName:(NSString*)name {
   return self initWithName:name trace:trace andHub:
    return ;
}*/

-(instancetype)initWithTransactionContext:(SentryTransactionContext*)context andHub:(SentryHub*)hub {
    return [self initWithName:context.name context:context andHub:hub];
}

-(instancetype)initWithName:(NSString*)name context:(nonnull SentrySpanContext *)context andHub:(nonnull SentryHub *)hub {
    if ([self init]) {
        self.transaction = name;
        //need to set the hub
        //self.hub = hub;
        self.startTimestamp = [NSDate date];
        trace = context ;
    }
    return self;
}


-(void)finish {
    self.timestamp = [NSDate date];
}

@end

