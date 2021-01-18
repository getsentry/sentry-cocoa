//
//  SentryTransactionContext.h
//  Sentry
//
//  Created by Dhiogo Brustolin on 18/01/21.
//  Copyright © 2021 Sentry. All rights reserved.
//

#import "SentrySpanContext.h"

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanId;

NS_SWIFT_NAME(TransactionContext)
@interface SentryTransactionContext : SentrySpanContext

@property (nonatomic, readonly) NSString *name;
@property (nonatomic) bool parentSampled;

- (instancetype)init;
- (instancetype)initWithName:(NSString *)name;
- (instancetype)initWithName:(NSString *)name
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(SentrySpanId *)parentSpanId
            andParentSampled:(BOOL)parentSampled;

@end

NS_ASSUME_NONNULL_END
