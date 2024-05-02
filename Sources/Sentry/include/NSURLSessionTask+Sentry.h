#import <Foundation/Foundation.h>

@interface SentryNSURLSessionTask : NSObject

+ (nullable NSString *)graphQLOperationNameFromTask:(NSURLSessionTask *_Nonnull)task;

@end
