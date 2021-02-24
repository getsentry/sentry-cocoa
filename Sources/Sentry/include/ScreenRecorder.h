
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScreenRecorder : NSObject

@property (class, nonatomic, readonly) ScreenRecorder *shared;

-(instancetype)init NS_UNAVAILABLE;

@property (readonly) BOOL isRecording;

-(bool) startWithTarget:(NSURL *)target;

-(bool) startWithTarget:(NSURL *)target
               duration:(NSTimeInterval)duration;

-(void) finish;

-(NSTimeInterval) recordingLength;

@end

NS_ASSUME_NONNULL_END
