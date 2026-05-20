#import <Foundation/Foundation.h>

@class SentryCompatStacktrace;

NS_ASSUME_NONNULL_BEGIN

/// A thread captured as part of an event payload.
@interface SentryCompatThread : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithThreadId:(nullable NSNumber *)threadId;

@property (nonatomic, strong, nullable) NSNumber *threadId;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, strong, nullable) SentryCompatStacktrace *stacktrace;
@property (nonatomic, strong, nullable) NSNumber *crashed;
@property (nonatomic, strong, nullable) NSNumber *current;
@property (nonatomic, strong, nullable) NSNumber *isMain;

@end

NS_ASSUME_NONNULL_END
