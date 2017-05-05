//
//  SentryException.h
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SentryThread;

@interface SentryException : NSObject

@property (nonatomic, copy) NSString * _Nonnull value;
@property (nonatomic, copy) NSString * _Nullable type;
@property (nonatomic, copy) NSDictionary<NSString *, id> * _Nullable mechanism;
@property (nonatomic, copy, getter=module, setter=setModule:) NSString * _Nullable module_;
@property (nonatomic) BOOL userReported;
@property (nonatomic, strong) SentryThread * _Nullable thread;

- (nonnull instancetype)initWithValue:(NSString * _Nonnull)value type:(NSString * _Nullable)type mechanism:(NSDictionary<NSString *, id> * _Nullable)mechanism module:(NSString * _Nullable)module_;
- (BOOL)isEqual:(id _Nullable)object;

@end
