#import "URLSessionTaskMock.h"
#import "SentryCurrentDateProvider.h"
#import "SentryDependencyContainer.h"

@implementation URLSessionDataTaskMock {
    NSURLRequest *_request;
    NSURLRequest *_currentRequest;
    NSURLResponse *_response;
    NSError *_error;
    NSDate *_resumeDate;
    NSURLSessionTaskState _state;
}

@dynamic state;

- (void)setState:(NSURLSessionTaskState)state
{
    _state = state;
}

- (NSURLSessionTaskState)state
{
    return _state;
}

- (NSURLRequest *)originalRequest
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
    _resumeDate = SentryDependencyContainer.sharedInstance.dateProvider.date;
}

- (int64_t)countOfBytesSent
{
    return DATA_BYTES_SENT;
}

- (int64_t)countOfBytesReceived
{
    return DATA_BYTES_RECEIVED;
}

- (NSURLRequest *)currentRequest
{
    return _currentRequest;
}

- (void)setCurrentRequest:(NSURLRequest *)request
{
    _currentRequest = request;
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
        _currentRequest = [_request mutableCopy];
    }
    return self;
}

#pragma clang diagnostic pop

@end

@implementation URLSessionDownloadTaskMock {
    NSURLRequest *_request;
    NSURLResponse *_response;
    NSURLSessionTaskState _state;
    NSError *_error;
}

@dynamic state;

- (void)setState:(NSURLSessionTaskState)state
{
    _state = state;
}

- (NSURLSessionTaskState)state
{
    return _state;
}

@dynamic error;

- (void)setError:(NSError *)error
{
    _error = error;
}

- (NSError *)error
{
    return _error;
}

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

- (int64_t)countOfBytesSent
{
    return DATA_BYTES_SENT;
}

- (int64_t)countOfBytesReceived
{
    return DATA_BYTES_RECEIVED;
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
    NSURLSessionTaskState _state;
    NSError *_error;
}

@dynamic state;

- (void)setState:(NSURLSessionTaskState)state
{
    _state = state;
}

- (NSURLSessionTaskState)state
{
    return _state;
}

@dynamic error;

- (void)setError:(NSError *)error
{
    _error = error;
}

- (NSError *)error
{
    return _error;
}

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

- (int64_t)countOfBytesSent
{
    return DATA_BYTES_SENT;
}

- (int64_t)countOfBytesReceived
{
    return DATA_BYTES_RECEIVED;
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
    NSURLSessionTaskState _state;
}

@dynamic state;

- (void)setState:(NSURLSessionTaskState)state
{
    _state = state;
}

- (NSURLSessionTaskState)state
{
    return _state;
}

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

@implementation URLSessionUnsupportedTaskMock

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (instancetype)initWithRequest:(NSURLRequest *)request
{
    if (self = [super init]) {
        // Empty on purpose
    }
    return self;
}
#pragma clang diagnostic pop

- (NSURLRequest *)currentRequest
{
    @throw @"currentRequest not available";
}

- (NSURLSessionTaskState) state {
    return  NSURLSessionTaskStateRunning;
}

@end
