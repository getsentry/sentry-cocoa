//
//  SentryContext.h
//  Sentry
//
//  Created by Daniel Griesser on 18/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Context)
@interface SentryContext : NSObject <SentrySerializable>

/**
 * Operating System information in contexts
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable osContext;

/**
 * Device information in contexts
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable deviceContext;

/**
 * App information in contexts
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable appContext;

/**
 * User set contexts should go here
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable customContext;


- (instancetype)init;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
