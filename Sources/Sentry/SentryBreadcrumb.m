//
//  SentryBreadcrumb.m
//  Sentry
//
//  Created by Daniel Griesser on 22/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryBreadcrumb.h>

#else
#import "SentryBreadcrumb.h"
#endif


@implementation SentryBreadcrumb

- (instancetype)initWithLevel:(enum SentrySeverity)level {
    self = [super init];
    if (self) {
        self.level = level;
    }
    return self;
}

- (NSDictionary<NSString *,id> *)serialized {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    [serializedData setValue:SentrySeverityNames[self.level] forKey:@"level"];

//    
//    
//    attributes.append(("category", category))
//    attributes.append(("timestamp", timestamp.iso8601))
//    attributes.append(("data", data))
//    attributes.append(("type", type))
//    attributes.append(("message", message))
//    attributes.append(("level", level.description))
//
    return serializedData;
}

@end
