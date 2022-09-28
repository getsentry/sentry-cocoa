//
//  SentryDescriptor.m
//  SentryObjc
//
//  Created by Dhiogo Brustolin on 28.09.22.
//  Copyright © 2022 Sentry. All rights reserved.
//

#import "SentryDescriptor.h"

@implementation SentryDescriptor

- (NSString *)getDescription:(id)object
{
    return [NSString stringWithFormat:@"%@", object];
}

@end
