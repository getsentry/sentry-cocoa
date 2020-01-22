//
//  SentryContext.m
//  Sentry
//
//  Created by Daniel Griesser on 18/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryContext.h>
#import <Sentry/SentryDefines.h>

#import <Sentry/SentryCrash.h>

#else
#import "SentryContext.h"
#import "SentryDefines.h"

#import "SentryCrash.h"
#endif

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentryContext

- (instancetype)init {
    return [super init];
}

- (NSDictionary<NSString *, id> *)serialize {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    [serializedData setValue:self.osContext forKey:@"os"];
    [self fixSystemName];
    [serializedData setValue:self.appContext forKey:@"app"];
    [serializedData setValue:self.deviceContext forKey:@"device"];
    [serializedData addEntriesFromDictionary:self.otherContexts];

    return serializedData;
}

- (void)fixSystemName {
    // This fixes iPhone OS to iOS because apple messed up the naming
    if (nil != self.osContext && [self.osContext[@"name"] isEqualToString:@"iPhone OS"]) {
        [self.osContext setValue:@"iOS" forKey:@"name"];
    }
}

@end

NS_ASSUME_NONNULL_END
