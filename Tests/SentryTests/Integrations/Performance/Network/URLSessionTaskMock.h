#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Written in Objective-C because Swift doesn't allow you to call the constructor of
 * NSURLSessionTask. Using suppression in implementation to override the init.
 */

static int64_t const DATA_BYTES_RECEIVED = 256;
static int64_t const DATA_BYTES_SENT = 652;

@protocol URLSessionTaskMock

@property (nonatomic) NSURLSessionTaskState state;

@end

@interface URLSessionDataTaskMock : NSURLSessionDataTask <URLSessionTaskMock>

@property (nullable, readonly) NSDate *resumeDate;
@property (nonatomic) NSURLSessionTaskState state;

- (instancetype)init;

- (instancetype)initWithRequest:(NSURLRequest *)request;

- (void)setResponse:(NSURLResponse *)response;

- (void)setError:(nullable NSError *)error;

- (void)setCurrentRequest:(NSURLRequest *)request;

@end

@interface URLSessionDownloadTaskMock : NSURLSessionDownloadTask <URLSessionTaskMock>

@property (nonatomic) NSURLSessionTaskState state;

@property (nonatomic, copy) NSError *error;

- (instancetype)initWithRequest:(NSURLRequest *)request;

- (void)setResponse:(NSURLResponse *)response;

@end

@interface URLSessionUploadTaskMock : NSURLSessionUploadTask <URLSessionTaskMock>

@property (nonatomic) NSURLSessionTaskState state;

- (instancetype)initWithRequest:(NSURLRequest *)request;

- (void)setResponse:(NSURLResponse *)response;

@end

@interface URLSessionStreamTaskMock : NSURLSessionStreamTask <URLSessionTaskMock>

@property (nonatomic) NSURLSessionTaskState state;

- (instancetype)initWithRequest:(NSURLRequest *)request;

- (void)setResponse:(NSURLResponse *)response;

@end

@interface URLSessionUnsupportedTaskMock : NSURLSessionTask <URLSessionTaskMock>

- (instancetype)initWithRequest:(NSURLRequest *)request;

- (NSURLRequest *)currentRequest NS_UNAVAILABLE;

- (NSURLSessionTaskState) state;

@end

NS_ASSUME_NONNULL_END
