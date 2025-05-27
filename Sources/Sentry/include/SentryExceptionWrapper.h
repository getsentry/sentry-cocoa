//
//  SentryExceptionWrapper.h
//  Sentry
//
//  Created by Itay Brenner on 27/5/25.
//  Copyright © 2025 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryThread;

/**
 * This is a helper class to identify exceptions that should use the stacktrace within
 */
@interface SentryExceptionWrapper : NSException

- (nullable instancetype)initWithException:(NSException *)exception;
- (NSArray<SentryThread *> *)buildThreads;

@end

NS_ASSUME_NONNULL_END
