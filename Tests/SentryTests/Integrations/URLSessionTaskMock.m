#import "URLSessionTaskMock.h"
#import "SentryCurrentDate.h"

@implementation URLSessionDataTaskMock {
    NSURLRequest *_request;
    NSURLResponse *_response;
    NSError *_error;
    NSDate *_resumeDate;
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

- (NSError *)error
{
    return _error;
}

- (void)setError:(NSError *)error
{
    _error = error;
}

- (void)resume
{
    _resumeDate = SentryCurrentDate.date;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

- (instancetype)init
{
    self = [super init];
    return self;
}

- (instancetype)initWithRequest:(NSURLRequest *)request
{
    if (self = [super init]) {
        _request = request;
    }
    return self;
}
#pragma clang diagnostic pop
@end

@implementation URLSessionDownloadTaskMock {
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

@implementation URLSessionUploadTaskMock {
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

@implementation URLSessionStreamTaskMock {
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
