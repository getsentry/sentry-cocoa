//
//  SentryStacktrace.h
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentrySerializable.h>

#else
#import "SentrySerializable.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryFrame;

@interface SentryStacktrace : NSObject <SentrySerializable>

@property(nonatomic, strong) NSArray<SentryFrame *> *frames;
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *registers;

- (instancetype)initWithFrames:(NSArray<SentryFrame *> *)frames
                     registers:(NSDictionary<NSString *, NSString *> *)registers;

@end

NS_ASSUME_NONNULL_END
