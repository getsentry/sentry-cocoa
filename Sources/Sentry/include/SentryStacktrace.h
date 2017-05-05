//
//  SentryStacktrace.h
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SentryFrame;

@interface SentryStacktrace : NSObject

@property (nonatomic, copy) NSArray<SentryFrame *> * _Nonnull frames;
@property (nonatomic, readonly, strong, getter=register) SentryRegister * _Nullable register_;
- (nonnull instancetype)initWithFrames:(NSArray<SentryFrame *> * _Nullable)frames;
- (nonnull instancetype)initWithFrames:(NSArray<SentryFrame *> * _Nullable)frames register:(SentryRegister * _Nullable)register_;

@end
