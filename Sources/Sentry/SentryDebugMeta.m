//
//  SentryDebugMeta.m
//  Sentry
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryDebugMeta.h>

#else
#import "SentryDebugMeta.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentryDebugMeta

- (instancetype)init {
    return [super init];
}

- (NSDictionary<NSString *, id> *)serialize {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    [serializedData setValue:self.uuid forKey:@"uuid"];
    [serializedData setValue:self.type forKey:@"type"];
    [serializedData setValue:self.imageAddress forKey:@"image_addr"];
    [serializedData setValue:self.imageSize forKey:@"image_size"];
    [serializedData setValue:[self.name lastPathComponent] forKey:@"name"];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
