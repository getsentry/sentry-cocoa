//
//  SentryGlobalEventProcessor.h
//  Sentry
//
//  Created by Klemens Mantzos on 22.01.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryEvent.h>
#else
#import "SentryEvent.h"
#endif

typedef SentryEvent *__nullable (^SentryEventProcessor)(SentryEvent *_Nonnull event);

NS_ASSUME_NONNULL_BEGIN

@interface SentryGlobalEventProcessor : NSObject 
SENTRY_NO_INIT

@property (nonatomic, strong) NSMutableArray<SentryEventProcessor> *processors;

+ (instancetype)shared;

- (void)addEventProcessor:(SentryEventProcessor)newProcessor;

@end

NS_ASSUME_NONNULL_END
