#import "SentryURLSessionTaskRequest.h"

@implementation SentryURLSessionTaskRequest

+ (nullable NSObject *)originalRequestOfTask:(NSURLSessionTask *)task
{
    return task.originalRequest;
}

+ (nullable NSObject *)currentRequestOfTask:(NSURLSessionTask *)task
{
    return task.currentRequest;
}

@end
