//
//  SentryStackLayer.h
//  Sentry
//
//  Created by Klemens Mantzos on 18.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryDefines.h>
#import <Sentry/SentryClient.h>
#import <Sentry/SentryScope.h>

#else
#import "SentryDefines.h"
#import "SentryClient.h"
#import "SentryScope.h"
#endif
NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(StackLayer)
@interface SentryStackLayer : NSObject
//SENTRY_NO_INIT

//- (instancetype)initWithClient:(SentryClient * _Nullable)client scope:(SentryScope *)scope;

// TODO(fetzig) make init stuff

@property(nonatomic, strong) SentryClient *_Nullable client;
@property(nonatomic, strong) SentryScope *_Nullable scope;

@end

NS_ASSUME_NONNULL_END
