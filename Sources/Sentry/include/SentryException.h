//
//  SentryException.h
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

@class SentryThread;

@interface SentryException : NSObject <SentrySerializable>

@property(nonatomic, copy) NSString *value;
@property(nonatomic, copy) NSString *type;
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable mechanism;
@property(nonatomic, copy) NSString *_Nullable module;
@property(nonatomic, copy) NSNumber *_Nullable userReported;
@property(nonatomic, strong) SentryThread *_Nullable thread;

- (instancetype)initWithValue:(NSString *)value type:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
