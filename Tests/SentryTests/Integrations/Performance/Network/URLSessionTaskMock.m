#import "URLSessionTaskMock.h"
#import "SentrySwift.h"

@implementation URLSessionDataTaskMock {
    NSURLRequest *_request;
    NSURLRequest *_currentRequest;
    NSURLResponse *_response;
    NSError *_error;
    NSDate *_resumeDate;
    NSURLSessionTaskState _state;
    NSLock *_lock;
}

@dynamic state;

- (void)setState:(NSURLSessionTaskState)state
{
    [_lock lock];
    _state = state;
    [_lock unlock];
}

- (NSURLSessionTaskState)state
{
    [_lock lock];
    NSURLSessionTaskState state = _state;
    [_lock unlock];
    return state;
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
    [_lock lock];
    NSURLRequest *request = _currentRequest;
    [_lock unlock];
    return request;
}

- (void)setCurrentRequest:(NSURLRequest *)request
{
    [_lock lock];
    _currentRequest = request;
    [_lock unlock];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

- (instancetype)init
{
    if (self = [super init]) {
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (instancetype)initWithRequest:(NSURLRequest *)request
{
    if (self = [super init]) {
        _lock = [[NSLock alloc] init];
        _request = request;
        _currentRequest = [_request mutableCopy];
    }
    return self;
}

#pragma clang diagnostic pop

@end

@implementation URLSessionDownloadTaskMock {
    NSURLRequest *_request;
    NSURLRequest *_currentRequest;
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
    return _currentRequest;
}

- (void)setCurrentRequest:(NSURLRequest *)request
{
    _currentRequest = request;
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
        _currentRequest = [_request mutableCopy];
    }
    return self;
}
#pragma clang diagnostic pop
@end

@implementation URLSessionUploadTaskMock {
    NSURLRequest *_request;
    NSURLRequest *_currentRequest;
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
    return _currentRequest;
}

- (void)setCurrentRequest:(NSURLRequest *)request
{
    _currentRequest = request;
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
        _currentRequest = [_request mutableCopy];
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

- (NSURLSessionTaskState)state
{
    return NSURLSessionTaskStateRunning;
}

@end

@implementation VolatileRequestTaskMock {
    NSUInteger _currentRequestAccessCount;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (instancetype)initWithRequest:(NSURLRequest *)request
{
    if (self = [super initWithRequest:request]) {
        _currentRequestAccessLimit = 1;
    }
    return self;
}
#pragma clang diagnostic pop

- (NSURLRequest *)currentRequest
{
    _currentRequestAccessCount++;
    if (_currentRequestAccessCount > self.currentRequestAccessLimit) {
        return nil;
    }
    return [super currentRequest];
}

@end

@implementation MutableRequestTaskMock {
    NSMutableURLRequest *_initialCurrentRequest;
    NSUInteger _setCurrentRequestCallCount;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (instancetype)initWithRequest:(NSURLRequest *)request
{
    if (self = [super initWithRequest:request]) {
        _initialCurrentRequest = (NSMutableURLRequest *)[super currentRequest];
    }
    return self;
}
#pragma clang diagnostic pop

- (NSMutableURLRequest *)initialCurrentRequest
{
    return _initialCurrentRequest;
}

- (NSUInteger)setCurrentRequestCallCount
{
    return _setCurrentRequestCallCount;
}

- (void)setCurrentRequest:(NSURLRequest *)request
{
    _setCurrentRequestCallCount++;
    [super setCurrentRequest:request];
}

@end
