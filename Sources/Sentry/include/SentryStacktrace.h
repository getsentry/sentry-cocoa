//
//  SentryStacktrace.h
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryDefines.h>
#import <Sentry/SentrySerializable.h>
#else
#import "SentryDefines.h"
#import "SentrySerializable.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryFrame;

NS_SWIFT_NAME(Stacktrace)
@interface SentryStacktrace : NSObject <SentrySerializable>
SENTRY_NO_INIT

@property(nonatomic, strong) NSArray<SentryFrame *> *frames;
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *registers;

- (instancetype)initWithFrames:(NSArray<SentryFrame *> *)frames
                     registers:(NSDictionary<NSString *, NSString *> *)registers;
- (void)fixDuplicateFrames;

@end

NS_ASSUME_NONNULL_END
