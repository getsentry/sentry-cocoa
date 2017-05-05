//
//  SentryException.h
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryThread;

@interface SentryException : NSObject

@property(nonatomic, copy) NSString *value;
@property(nonatomic, copy) NSString *_Nullable type;
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable mechanism;
@property(nonatomic, copy) NSString *_Nullable module;
@property(nonatomic) BOOL userReported;
@property(nonatomic, strong) SentryThread *_Nullable thread;

//- (nonnull instancetype)initWithValue:(NSString *_Nonnull)value type:(NSString *_Nullable)type
//                            mechanism:(NSDictionary<NSString *, id> *_Nullable)mechanism
//                               module:(NSString *_Nullable)module_;
//
//- (BOOL)isEqual:(id _Nullable)object;

@end

NS_ASSUME_NONNULL_END
