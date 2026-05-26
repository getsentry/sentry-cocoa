#import <Foundation/Foundation.h>

@class SentryObjCFrame;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCStacktrace : NSObject

@property (nonatomic, strong) NSArray<SentryObjCFrame *> *frames;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *registers;
@property (nonatomic, copy, nullable) NSNumber *snapshot;

- (instancetype)initWithFrames:(NSArray<SentryObjCFrame *> *)frames
                     registers:(NSDictionary<NSString *, NSString *> *)registers;

@end

NS_ASSUME_NONNULL_END
