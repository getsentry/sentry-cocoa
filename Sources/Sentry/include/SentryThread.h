//
//  SentryThread.h
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

@class SentryStacktrace;

@interface SentryThread : NSObject <SentrySerializable>

@property(nonatomic, copy) NSNumber *threadId;
@property(nonatomic, copy) NSString *_Nullable name;
@property(nonatomic, strong) SentryStacktrace *_Nullable stacktrace;
@property(nonatomic, copy) NSString *_Nullable reason;

//- (nonnull instancetype)initWithId:(NSInteger)threadId
//                           crashed:(BOOL)crashed
//                           current:(BOOL)current
//                              name:(NSString * _Nullable)name
//                        stacktrace:(SentryStacktrace * _Nullable)stacktrace
//                            reason:(NSString * _Nullable)reason;
//
//@property (nonatomic, readonly, copy) NSString * _Nonnull debugDescription;

@end

NS_ASSUME_NONNULL_END
