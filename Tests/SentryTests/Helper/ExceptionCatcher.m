//
//  ExceptionCatcher.m
//  Sentry
//
//  Created by Itay Brenner on 27/5/25.
//  Copyright © 2025 Sentry. All rights reserved.
//

#import "ExceptionCatcher.h"

@implementation ExceptionCatcher

+ (NSException *)tryBlock:(void (^)(void))tryBlock
{
    @try {
        tryBlock();
        return nil;
    } @catch (NSException *exception) {
        return exception;
    }
}

@end
