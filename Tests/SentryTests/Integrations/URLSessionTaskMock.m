//
//  URLSessionTaskMock.m
//  SentryTests
//
//  Created by Dhiogo Brustolin on 21/06/21.
//  Copyright © 2021 Sentry. All rights reserved.
//

#import "URLSessionTaskMock.h"

@implementation URLSessionTaskMock {
    NSURLRequest *_request;
}

@dynamic state;

- (NSURLRequest *)currentRequest
{
    return _request;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (instancetype)initWithRequest:(NSURLRequest *)request
{
    if (self = [super init]) {
        _request = request;
    }
    return self;
}
#pragma clang diagnostic pop
@end
