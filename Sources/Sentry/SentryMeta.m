//
//  SentryMeta.m
//  Sentry
//
//  Created by Klemens Mantzos on 08.01.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

#import "SentryMeta.h"

@implementation SentryMeta

NSString *const versionString = @"4.4.3";
NSString *const sdkName = @"sentry-cocoa";

+ (NSString *)versionString {
    return versionString;
}

+ (NSString *)sdkName {
    return sdkName;
}

@end
