//
//  SentryThread.h
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SentryStacktrace;

@interface SentryThread : NSObject

@property(nonatomic, readonly) NSInteger id;
@property(nonatomic, readonly, copy) NSString *_Nullable name;
@property(nonatomic, readonly, strong) SentryStacktrace *_Nullable stacktrace;
@property(nonatomic, readonly, copy) NSString *_Nullable reason;

//- (nonnull instancetype)initWithId:(NSInteger)threadId
//                           crashed:(BOOL)crashed
//                           current:(BOOL)current
//                              name:(NSString * _Nullable)name
//                        stacktrace:(SentryStacktrace * _Nullable)stacktrace
//                            reason:(NSString * _Nullable)reason;
//
//@property (nonatomic, readonly, copy) NSString * _Nonnull debugDescription;


@end
