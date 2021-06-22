#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface URLSessionTaskMock : NSURLSessionTask

@property (nonatomic) NSURLSessionTaskState state;

- (instancetype)initWithRequest:(NSURLRequest *)request;

@end

NS_ASSUME_NONNULL_END
