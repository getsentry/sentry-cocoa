
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentrySessionRecorder : NSObject
@property (class, nonatomic, readonly) SentrySessionRecorder *shared;

- (instancetype)init NS_UNAVAILABLE;

@property (readonly) BOOL isRecording;

- (bool)start;

- (void)stop;

- (nullable NSURL *)fileUrlForRecording:(NSString *)recordName;

- (nullable NSURL *)currentRecording;
- (NSArray<NSString *> *)availableRecording;
@end

NS_ASSUME_NONNULL_END
