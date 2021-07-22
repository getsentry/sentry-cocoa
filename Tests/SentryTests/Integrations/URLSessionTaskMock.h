#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Written in Objective-C because Swift doesn't allow you to call the constructor of
 * NSURLSessionTask. Using suppression in implementation to override the init.
 */

@interface URLSessionDataTaskMock : NSURLSessionDataTask

@property (nullable, readonly) NSDate *resumeDate;
@property (nonatomic) NSURLSessionTaskState state;

- (instancetype)initWithRequest:(NSURLRequest *)request;

- (void)setResponse:(NSURLResponse *)response;

- (void)setError:(nullable NSError *)error;

@end

@interface URLSessionDownloadTaskMock : NSURLSessionDownloadTask
@property (nonatomic) NSURLSessionTaskState state;

- (instancetype)initWithRequest:(NSURLRequest *)request;

- (void)setResponse:(NSURLResponse *)response;

@end

@interface URLSessionUploadTaskMock : NSURLSessionUploadTask

@property (nonatomic) NSURLSessionTaskState state;

- (instancetype)initWithRequest:(NSURLRequest *)request;

- (void)setResponse:(NSURLResponse *)response;

@end

@interface URLSessionStreamTaskMock : NSURLSessionStreamTask

@property (nonatomic) NSURLSessionTaskState state;

- (instancetype)initWithRequest:(NSURLRequest *)request;

- (void)setResponse:(NSURLResponse *)response;

@end

NS_ASSUME_NONNULL_END
