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

- (instancetype)initWithUuid:(NSString *)uuid {
    self = [super init];
    if (self) {
        self.uuid = uuid;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialized {
    NSMutableDictionary *serializedData = @{
                                            @"uuid": self.uuid
                                            }.mutableCopy;
    
    [serializedData setValue:self.type forKey:@"type"];
    [serializedData setValue:self.cpuType forKey:@"cpu_type"];
    [serializedData setValue:self.cpuSubType forKey:@"cpu_subtype"];
    [serializedData setValue:self.imageVmAddress forKey:@"image_vmaddr"];
    [serializedData setValue:self.imageAddress forKey:@"image_addr"];
    [serializedData setValue:self.imageSize forKey:@"image_size"];
    [serializedData setValue:self.name forKey:@"name"];
    [serializedData setValue:self.majorVersion forKey:@"major_version"];
    [serializedData setValue:self.minorVersion forKey:@"minor_version"];
    [serializedData setValue:self.revisionVersion forKey:@"revision_version"];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
