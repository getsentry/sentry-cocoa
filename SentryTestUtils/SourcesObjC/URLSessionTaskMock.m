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
    [_lock lock];
    NSURLRequest *request = _request;
    [_lock unlock];
    return request;
}

- (NSURLResponse *)response
{
    [_lock lock];
    NSURLResponse *response = _response;
    [_lock unlock];
    return response;
}

- (void)setResponse:(NSURLResponse *)response
{
    [_lock lock];
    _response = response;
    [_lock unlock];
}

- (NSError *)error
{
    [_lock lock];
    NSError *error = _error;
    [_lock unlock];
    return error;
}

- (void)setError:(NSError *)error
{
    [_lock lock];
    _error = error;
    [_lock unlock];
}

- (NSDate *)resumeDate
{
    [_lock lock];
    NSDate *resumeDate = _resumeDate;
    [_lock unlock];
    return resumeDate;
}

- (void)resume
{
    [_lock lock];
    _resumeDate = SentryDependencyContainer.sharedInstance.dateProvider.date;
    [_lock unlock];
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

@dynamic error;

- (void)setError:(NSError *)error
{
    [_lock lock];
    _error = error;
    [_lock unlock];
}

- (NSError *)error
{
    [_lock lock];
    NSError *error = _error;
    [_lock unlock];
    return error;
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

- (NSURLResponse *)response
{
    [_lock lock];
    NSURLResponse *response = _response;
    [_lock unlock];
    return response;
}

- (void)setResponse:(NSURLResponse *)response
{
    [_lock lock];
    _response = response;
    [_lock unlock];
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
        _lock = [[NSLock alloc] init];
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

@dynamic error;

- (void)setError:(NSError *)error
{
    [_lock lock];
    _error = error;
    [_lock unlock];
}

- (NSError *)error
{
    [_lock lock];
    NSError *error = _error;
    [_lock unlock];
    return error;
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

- (NSURLResponse *)response
{
    [_lock lock];
    NSURLResponse *response = _response;
    [_lock unlock];
    return response;
}

- (void)setResponse:(NSURLResponse *)response
{
    [_lock lock];
    _response = response;
    [_lock unlock];
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
        _lock = [[NSLock alloc] init];
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

- (NSURLRequest *)currentRequest
{
    [_lock lock];
    NSURLRequest *request = _request;
    [_lock unlock];
    return request;
}

- (NSURLResponse *)response
{
    [_lock lock];
    NSURLResponse *response = _response;
    [_lock unlock];
    return response;
}

- (void)setResponse:(NSURLResponse *)response
{
    [_lock lock];
    _response = response;
    [_lock unlock];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (instancetype)initWithRequest:(NSURLRequest *)request
{
    if (self = [super init]) {
        _lock = [[NSLock alloc] init];
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
    NSUInteger _currentRequestAccessLimit;
    NSLock *_lock;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (instancetype)initWithRequest:(NSURLRequest *)request
{
    if (self = [super initWithRequest:request]) {
        _lock = [[NSLock alloc] init];
        _currentRequestAccessLimit = 1;
    }
    return self;
}
#pragma clang diagnostic pop

- (NSUInteger)currentRequestAccessLimit
{
    [_lock lock];
    NSUInteger limit = _currentRequestAccessLimit;
    [_lock unlock];
    return limit;
}

- (void)setCurrentRequestAccessLimit:(NSUInteger)currentRequestAccessLimit
{
    [_lock lock];
    _currentRequestAccessLimit = currentRequestAccessLimit;
    [_lock unlock];
}

- (NSURLRequest *)currentRequest
{
    [_lock lock];
    _currentRequestAccessCount++;
    BOOL isBeyondAccessLimit = _currentRequestAccessCount > _currentRequestAccessLimit;
    [_lock unlock];

    if (isBeyondAccessLimit) {
        return nil;
    }
    return [super currentRequest];
}

@end

@implementation MutableRequestTaskMock {
    NSMutableURLRequest *_initialCurrentRequest;
    NSUInteger _setCurrentRequestCallCount;
    NSLock *_lock;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (instancetype)initWithRequest:(NSURLRequest *)request
{
    if (self = [super initWithRequest:request]) {
        _lock = [[NSLock alloc] init];
        _initialCurrentRequest = (NSMutableURLRequest *)[super currentRequest];
    }
    return self;
}
#pragma clang diagnostic pop

- (NSMutableURLRequest *)initialCurrentRequest
{
    [_lock lock];
    NSMutableURLRequest *request = _initialCurrentRequest;
    [_lock unlock];
    return request;
}

- (NSUInteger)setCurrentRequestCallCount
{
    [_lock lock];
    NSUInteger callCount = _setCurrentRequestCallCount;
    [_lock unlock];
    return callCount;
}

- (void)setCurrentRequest:(NSURLRequest *)request
{
    [_lock lock];
    _setCurrentRequestCallCount++;
    [_lock unlock];
    [super setCurrentRequest:request];
}

@end
