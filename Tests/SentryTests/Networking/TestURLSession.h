#import "URLSessionTaskMock.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TestURLSession : NSURLSession

@property (nullable, nonatomic, strong) NSDate *invalidateAndCancelDate;
@property (nullable, nonatomic, strong) URLSessionDataTaskMock *lastDataTask;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
