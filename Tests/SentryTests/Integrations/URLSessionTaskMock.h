//
//  URLSessionTaskMock.h
//  SentryTests
//
//  Created by Dhiogo Brustolin on 21/06/21.
//  Copyright © 2021 Sentry. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface URLSessionTaskMock : NSURLSessionTask

@property (nonatomic) NSURLSessionTaskState state;

- (instancetype)initWithRequest:(NSURLRequest *)request;

@end

NS_ASSUME_NONNULL_END
