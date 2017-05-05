//
//  SentryStacktrace.h
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryFrame;

@interface SentryStacktrace : NSObject

@property(nonatomic, copy) NSArray<SentryFrame *> *frames;
@property(nonatomic, readonly, strong) NSDictionary<NSString *, NSString *> *registers;

//- (nonnull instancetype)initWithFrames:(NSArray<SentryFrame *> *_Nullable)frames;
//
//- (nonnull instancetype)initWithFrames:(NSArray<SentryFrame *> *_Nullable)frames
//                              register:(SentryRegister *_Nullable)register_;

@end

NS_ASSUME_NONNULL_END
