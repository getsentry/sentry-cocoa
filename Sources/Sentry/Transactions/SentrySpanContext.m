//
//  SpanContext.m
//  Sentry
//
//  Created by Dhiogo Brustolin on 05/01/21.
//  Copyright © 2021 Sentry. All rights reserved.
//

#import "SentrySpanContext.h"
#import "SentryId.h"
#import "SentrySpanId.h"

@interface
SentrySpanContext () {
    NSMutableDictionary<NSString *, NSString *> *_tags;
}

@end

@implementation SentrySpanContext

- (instancetype)init
{
    return [self initWithtraceId:[[SentryId alloc] init]
                          spanId:[[SentrySpanId alloc] init]
                        parentId:nil
                      andSampled:false];
}

- (instancetype)initWithSampled:(BOOL)sampled
{
    return [self initWithtraceId:[[SentryId alloc] init]
                          spanId:[[SentrySpanId alloc] init]
                        parentId:nil
                      andSampled:sampled];
}

- (instancetype)initWithtraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(SentrySpanId *_Nullable)parentId
                     andSampled:(BOOL)sampled
{
    if (self = [super init]) {
        self.traceId = traceId;
        self.spanId = spanId;
        self.parentSpanId = parentId;
        self.sampled = sampled;
    }
    return self;
}

- (NSMutableDictionary *)tags
{
    if (_tags == nil)
        _tags = [[NSMutableDictionary alloc] init];
    return _tags;
}

@end
