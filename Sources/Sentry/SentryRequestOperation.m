//
//  SentryRequestOperation.m
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryRequestOperation.h>
#else
#import "SentryRequestOperation.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryRequestOperation()

@property (nonatomic, retain) NSURLSessionTask *task;
@property (nonatomic, retain) NSURLRequest *request;

@end

@implementation SentryRequestOperation

- (instancetype)initWithSession:(NSURLSession *)session request:(NSURLRequest *)request completionHandler:(_Nullable SentryQueueableRequestManagerHandler)completionHandler {
    self = [super init];
    if (self) {
        self.request = request;
        self.task = [session dataTaskWithRequest:self.request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (completionHandler) {
                completionHandler(error);
            }
            [self completeOperation];
        }];
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
