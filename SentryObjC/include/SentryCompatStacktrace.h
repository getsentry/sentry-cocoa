#import <Foundation/Foundation.h>

@class SentryCompatFrame;

NS_ASSUME_NONNULL_BEGIN

/// A stack trace, composed of frames plus optional register state.
@interface SentryCompatStacktrace : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithFrames:(NSArray<SentryCompatFrame *> *)frames
                     registers:(NSDictionary<NSString *, NSString *> *)registers;

@property (nonatomic, copy) NSArray<SentryCompatFrame *> *frames;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *registers;
@property (nonatomic, strong, nullable) NSNumber *snapshot;

- (void)fixDuplicateFrames;

@end

NS_ASSUME_NONNULL_END
