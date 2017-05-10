//
//  SentryDebugMeta.h
//  Sentry
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryDefines.h>
#import <Sentry/SentrySerializable.h>
#else
#import "SentryDefines.h"
#import "SentrySerializable.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryDebugMeta : NSObject <SentrySerializable>

@property(nonatomic, copy) NSString *uuid;

@property(nonatomic, copy) NSString *_Nullable type;
@property(nonatomic, assign) NSInteger cpuType;
@property(nonatomic, assign) NSInteger cpuSubType;

@property(nonatomic, copy) NSString *_Nullable name;
@property(nonatomic, assign) NSInteger imageSize;
@property(nonatomic, copy) NSString *_Nullable imageVmAddress;
@property(nonatomic, copy) NSString *_Nullable imageAddress;

@property(nonatomic, assign) NSInteger majorVersion;
@property(nonatomic, assign) NSInteger minorVersion;
@property(nonatomic, assign) NSInteger revisionVersion;

- (instancetype)initWithUuid:(NSString *)uuid;

@end

NS_ASSUME_NONNULL_END
