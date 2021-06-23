#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface URLSessionTaskMock : NSURLSessionTask

@property (nonatomic) NSURLSessionTaskState state;

- (instancetype)initWithRequest:(NSURLRequest *)request;

- (void)setResponse:(NSURLResponse *)response;

@end

NS_ASSUME_NONNULL_END
