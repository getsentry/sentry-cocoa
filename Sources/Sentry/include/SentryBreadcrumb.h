//
//  SentryBreadcrumb.h
//  Sentry
//
//  Created by Daniel Griesser on 22/05/2017.
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

NS_SWIFT_NAME(Breadcrumb)
@interface SentryBreadcrumb : NSObject <SentrySerializable>
SENTRY_NO_INIT

@property(nonatomic) enum SentrySeverity level;
@property(nonatomic, copy) NSString *category;

@property(nonatomic, strong) NSDate *_Nullable timestamp;
@property(nonatomic, copy) NSString *_Nullable type;
@property(nonatomic, copy) NSString *_Nullable message;
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable data;

- (instancetype)initWithLevel:(enum SentrySeverity)level category:(NSString *)category;

@end

NS_ASSUME_NONNULL_END
