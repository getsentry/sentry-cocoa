//
//  SentryMeta.m
//  Sentry
//
//  Created by Klemens Mantzos on 08.01.20.
//  Copyright © 2020 Sentry. All rights reserved.
//


#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryMeta.h>

#else

#import "SentryMeta.h"

#endif

@implementation SentryMeta

NSString *const versionString = @"5.0.0-beta.0";
NSString *const sdkName = @"sentry.cocoa";

+ (NSString *)versionString {
    return versionString;
}

+ (NSString *)sdkName {
    return sdkName;
}

@end
