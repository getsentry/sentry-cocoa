//
//  SentryFrame.m
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryFrame.h>
#else
#import "SentryFrame.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentryFrame

- (instancetype)initWithFileName:(NSString *)fileName function:(NSString *)function module:(NSString *)module {
    self = [super init];
    if (self) {
        self.fileName = fileName;
        self.function = function;
        self.module = module;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialized {
    NSMutableDictionary *serializedData = @{
                                            @"filename": self.fileName,
                                            @"function": self.function,
                                            @"module": self.module,
                                            }.mutableCopy;
    
    [serializedData setValue:self.lineNumber forKey:@"lineno"];
    [serializedData setValue:self.columnNumber forKey:@"colno"];
    [serializedData setValue:self.package forKey:@"package"];
    [serializedData setValue:self.imageAddress forKey:@"image_addr"];
    [serializedData setValue:self.instructionAddress forKey:@"instruction_addr"];
    [serializedData setValue:self.symbolAddress forKey:@"symbol_addr"];
    [serializedData setValue:self.platform forKey:@"platform"];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
