#import <Foundation/Foundation.h>

@class SOCSentryStacktrace;

NS_ASSUME_NONNULL_BEGIN

/// A thread captured as part of an event payload.
@interface SOCSentryThread : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithThreadId:(nullable NSNumber *)threadId;

@property (nonatomic, strong, nullable) NSNumber *threadId;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, strong, nullable) SOCSentryStacktrace *stacktrace;
@property (nonatomic, strong, nullable) NSNumber *crashed;
@property (nonatomic, strong, nullable) NSNumber *current;
@property (nonatomic, strong, nullable) NSNumber *isMain;

@end

NS_ASSUME_NONNULL_END
