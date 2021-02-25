//
//  SentryTransactionSamplingContext.m
//  Sentry
//
//  Created by Dhiogo Brustolin on 24/02/21.
//  Copyright © 2021 Sentry. All rights reserved.
//

#import "SentryTransactionSamplingContext.h"

@implementation SentryTransactionSamplingContext


- (instancetype) initWithTransactionContext:(SentryTransactionContext *) transactionContext
                      customSamplingContext:(NSDictionary<NSString *, id> *) customSamplingContext {
    if (self = [super init]) {
        _transactionContext = transactionContext;
        _customSamplingContext = customSamplingContext;
    }
    return self;
}

@end
