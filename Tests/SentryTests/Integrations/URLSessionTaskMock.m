#import "URLSessionTaskMock.h"

@implementation URLSessionTaskMock {
    NSURLRequest *_request;
    NSURLResponse *_response;
}

@dynamic state;

- (NSURLRequest *)currentRequest
{
    return _request;
}

- (NSURLResponse *)response
{
    return _response;
}

- (void)setResponse:(NSURLResponse *)response
{
    _response = response;
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
