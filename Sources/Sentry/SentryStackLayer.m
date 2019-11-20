//
//  SentryStackLayer.m
//  Sentry
//
//  Created by Klemens Mantzos on 18.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryStackLayer.h>
#else
#import "SentryStackLayer.h"
#endif

@implementation SentryStackLayer

- (instancetype)initWithClient:(SentryClient *)client scope:(SentryScope *)scope {
    if (self = [super init]) {
        [self setScope:scope];
        [self setClient:client];
    }
    return self;
}

@end


