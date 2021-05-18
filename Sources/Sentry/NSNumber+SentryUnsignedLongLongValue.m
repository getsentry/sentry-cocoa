//
//  NSNumber+SentryUnsignedLongLongValue.m
//  Sentry
//
//  Created by MingLQ on 2021-05-18.
//  Copyright © 2021 Sentry. All rights reserved.
//

#import "NSNumber+SentryUnsignedLongLongValue.h"

@implementation NSNumber (SentryUnsignedLongLongValue)

- (unsigned long long)sentry_unsignedLongLongValue
{
    return [self unsignedLongLongValue];
}

@end
