//
//  SentryStackLayer.h
//  Sentry
//
//  Created by Klemens Mantzos on 18.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentryClient.h"
#import "SentryScope.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(StackLayer)
@interface SentryStackLayer : NSObject

@property(nonatomic, strong) SentryClient *_Nullable client;
@property(nonatomic, strong) SentryScope *_Nullable scope;

@end

NS_ASSUME_NONNULL_END
