//
//  SentryGlobalEventProcessor.m
//  Sentry
//
//  Created by Klemens Mantzos on 22.01.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryGlobalEventProcessor.h>
#import <Sentry/SentryLog.h>

#else
#import "SentryGlobalEventProcessor.h"
#import "SentryLog.h"
#endif

@implementation SentryGlobalEventProcessor

+ (instancetype)shared {
    static SentryGlobalEventProcessor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initPrivate];
    });
    return instance;
}

- (instancetype)initPrivate {
    if (self = [super init]) {
        self.processors = [NSMutableArray new];
    }
    return self;
}

- (void)addEventProcessor:(SentryEventProcessor)newProcessor {
    [self.processors addObject:newProcessor];
}

@end
