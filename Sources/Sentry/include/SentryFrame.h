//
//  SentryFrame.h
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SentryFrame : NSObject

@property (nonatomic, copy) NSString * _Nullable fileName;
@property (nonatomic, copy) NSString * _Nullable function;
@property (nonatomic, copy, getter=module, setter=setModule:) NSString * _Nullable module_;
@property (nonatomic, copy) NSString * _Nullable package;
@property (nonatomic, copy) NSString * _Nullable imageAddress;
@property (nonatomic, copy) NSString * _Nullable platform;
@property (nonatomic, copy) NSString * _Nullable instructionAddress;
@property (nonatomic, copy) NSString * _Nullable symbolAddress;
- (nonnull instancetype)initWithFileName:(NSString * _Nullable)fileName function:(NSString * _Nullable)function module:(NSString * _Nullable)module_ line:(NSInteger)line;
- (nonnull instancetype)initWithFileName:(NSString * _Nullable)fileName function:(NSString * _Nullable)function module:(NSString * _Nullable)module_ line:(NSInteger)line column:(NSInteger)column;

@end
