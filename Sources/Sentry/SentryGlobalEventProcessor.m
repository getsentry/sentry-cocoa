//
//  SentryGlobalEventProcessor.m
//  Sentry
//
//  Created by Klemens Mantzos on 22.01.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

#import "SentryGlobalEventProcessor.h"

@implementation SentryGlobalEventProcessor

@synthesize processors = _processors;

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

- (BOOL)addEventProcessor:(SentryEventProcessor)newProcessor {
    NSLog(@"addEventProcessor before %lu", (unsigned long)self.processors.count);
    [self.processors addObject:newProcessor];
    NSLog(@"addEventProcessor after %lu", (unsigned long)self.processors.count);
    return YES;
}

@end
