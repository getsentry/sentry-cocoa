#import "SentryEnvelopeItemHeader.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryReplayEnvelopeItemHeader : SentryEnvelopeItemHeader

@property (nonatomic) NSInteger segmentId;

- (instancetype)initWithType:(NSString *)type
                   segmentId:(NSInteger)segmentId
                      length:(NSUInteger)length;

+ (instancetype)replayRecordingHeaderWithSegmentId:(NSInteger)segmentId length:(NSUInteger)length;

+ (instancetype)replayVideoHeaderWithSegmentId:(NSInteger)segmentId length:(NSUInteger)length;

@end

NS_ASSUME_NONNULL_END
