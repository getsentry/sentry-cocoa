#import <Foundation/Foundation.h>

@class SOCSentryFrame;

NS_ASSUME_NONNULL_BEGIN

/// A stack trace, composed of frames plus optional register state.
@interface SOCSentryStacktrace : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithFrames:(NSArray<SOCSentryFrame *> *)frames
                     registers:(NSDictionary<NSString *, NSString *> *)registers;

@property (nonatomic, copy) NSArray<SOCSentryFrame *> *frames;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *registers;
@property (nonatomic, strong, nullable) NSNumber *snapshot;

- (void)fixDuplicateFrames;

@end

NS_ASSUME_NONNULL_END
