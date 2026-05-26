#import <Foundation/Foundation.h>

@class SentryObjCStacktrace;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCThread : NSObject

@property (nonatomic, copy, nullable) NSNumber *threadId;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, strong, nullable) SentryObjCStacktrace *stacktrace;
@property (nonatomic, copy, nullable) NSNumber *crashed;
@property (nonatomic, copy, nullable) NSNumber *current;
@property (nonatomic, copy, nullable) NSNumber *isMain;

- (instancetype)initWithThreadId:(nullable NSNumber *)threadId;

@end

NS_ASSUME_NONNULL_END
