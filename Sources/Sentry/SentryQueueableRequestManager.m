//
//  SentryQueueableRequestManager.m
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryQueueableRequestManager.h>
#else
#import "SentryQueueableRequestManager.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryQueueableRequestManager ()

@property(nonatomic, strong) NSOperationQueue *queue;
@property(nonatomic, strong) NSURLSession *session;

@end

@implementation SentryQueueableRequestManager

- (instancetype)initWithSession:(NSURLSession *)session {
    self = [super init];
    if (self) {
        self.session = session;
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.name = @"io.sentry.QueueableRequestManager.OperationQueue";
        self.queue.maxConcurrentOperationCount = 3;
    }
    return self;
}

- (BOOL)isReady {
    // We always have at least one operation in the queue when calling this
    return self.queue.operationCount <= 1;
}

- (void)addRequest:(NSURLRequest *)request completionHandler:(_Nullable SentryRequestFinished)completionHandler {
    
}

@end

NS_ASSUME_NONNULL_END
