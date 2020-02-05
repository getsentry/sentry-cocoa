//
//  SentryRequestOperation.h
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SentryQueueableRequestManager.h"
#import "SentryAsynchronousOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryRequestOperation : SentryAsynchronousOperation

- (instancetype)initWithSession:(NSURLSession *)session request:(NSURLRequest *)request
              completionHandler:(_Nullable SentryRequestOperationFinished)completionHandler;

@end

NS_ASSUME_NONNULL_END
