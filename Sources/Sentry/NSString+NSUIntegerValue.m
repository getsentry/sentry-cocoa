//
//  NSString+NSUIntegerValue.m
//  Sentry
//
//  Created by Crazy凡 on 2019/3/21.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import "NSString+NSUIntegerValue.h"

@implementation NSString (NSUIntegerValue)

- (NSUInteger)unsignedLongLongValue {
    return [self integerValue];
}

@end
