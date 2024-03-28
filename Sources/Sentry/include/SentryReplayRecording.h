#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryReplayEncoding = @"h264";
static NSString *const SentryReplayContainer = @"mp4";
static NSString *const SentryReplayFrameRateType = @"constant";

@interface SentryReplayRecording : NSObject

@property (nonatomic) NSInteger segmentId;

/**
 * Video file size
 */
@property (nonatomic) NSInteger size;

@property (nonatomic, strong) NSDate *start;

@property (nonatomic) NSTimeInterval duration;

@property (nonatomic) NSInteger frameCount;

@property (nonatomic) NSInteger frameRate;

@property (nonatomic) NSInteger height;

@property (nonatomic) NSInteger width;

- (instancetype)initWithSegmentId:(NSInteger)segmentId
                             size:(NSInteger)size
                            start:(NSDate *)start
                         duration:(NSTimeInterval)duration
                       frameCount:(NSInteger)frameCount
                        frameRate:(NSInteger)frameRate
                           height:(NSInteger)height
                            width:(NSInteger)width;

- (NSArray<NSDictionary<NSString *, id> *> *)serialize;

- (NSDictionary<NSString *, id> *)headerForReplayRecording;

@end

NS_ASSUME_NONNULL_END
