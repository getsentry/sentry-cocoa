#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Written in Objective-C because Swift doesn't allow you to call the constructor of
 * NSURLSessionTask. Using suppression in implementation to override the init.
 */
@interface URLSessionTaskMock : NSURLSessionDataTask

@property (nonatomic) NSURLSessionTaskState state;

- (instancetype)initWithRequest:(NSURLRequest *)request;

- (void)setResponse:(NSURLResponse *)response;

@end

NS_ASSUME_NONNULL_END
