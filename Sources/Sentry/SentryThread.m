//
//  SentryThread.m
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryThread.h>
#import <Sentry/SentryStacktrace.h>

#else
#import "SentryThread.h"
#import "SentryStacktrace.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentryThread

- (instancetype)initWithThreadId:(NSNumber *)threadId {
    self = [super init];
    if (self) {
        self.threadId = threadId;
    }
    return self;
}

+ (NSRegularExpression *)frameRegex {
    static dispatch_once_t onceTokenRegex;
    static NSRegularExpression *regex = nil;
    dispatch_once(&onceTokenRegex, ^{
        NSString *pattern = @"([^\\s]+)";
        regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    });
    return regex;
}


// We are passing a string since going through the callstack array entry by entry we only would get
// the memory addresses
- (instancetype)initWithCallStack:(NSString *)callstack {
    self = [super init];
//    NSLog(@"a %@", [NSThread callStackSymbols]);
//    NSLog(@"b %@", [NSThread callStackReturnAddresses]);

    NSCharacterSet *separatorSet = [NSCharacterSet characterSetWithCharactersInString:@"\n"];
    NSMutableArray *array = [NSMutableArray arrayWithArray:[callstack componentsSeparatedByCharactersInSet:separatorSet]];
    [array removeObject:@"("];
    [array removeObject:@")"];
    
    NSString *frame = [array objectAtIndex:0];
    NSRange searchedRange = NSMakeRange(0, [frame length]);
    NSArray *matches = [[self.class frameRegex] matchesInString:frame options:0 range:searchedRange];
    NSLog(@"matches %@", matches);
//    NSMutableArray *strings = [NSMutableArray array];
    for (NSTextCheckingResult *match in matches) {
        NSLog(@"%@", [frame substringWithRange:[match rangeAtIndex:1]]);
    }

    return self;
}

- (NSDictionary<NSString *, id> *)serialize {
    NSMutableDictionary *serializedData = @{
            @"id": self.threadId ? self.threadId : @(99)
    }.mutableCopy;

    [serializedData setValue:self.crashed forKey:@"crashed"];
    [serializedData setValue:self.current forKey:@"current"];
    [serializedData setValue:self.name forKey:@"name"];
    [serializedData setValue:[self.stacktrace serialize] forKey:@"stacktrace"];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
