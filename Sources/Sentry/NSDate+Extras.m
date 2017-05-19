//
//  NSDate+Extras.m
//  Sentry
//
//  Created by Daniel Griesser on 19/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import "NSDate+Extras.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSDate (Extras)

+ (NSDateFormatter *)getIso8601Formatter {
    static NSDateFormatter *isoFormatter = nil;
    if (nil == isoFormatter) {
        isoFormatter = [[NSDateFormatter alloc] init];
        [isoFormatter setLocale: [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        isoFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation: @"UTC"];
        [isoFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
    }
    return isoFormatter;
}

+ (NSDate *)fromIso8601String:(NSString *)string {
    return [[self.class getIso8601Formatter] dateFromString:string];
}

@end

NS_ASSUME_NONNULL_END
