#import <Foundation/Foundation.h>

@class SentryObjCOptions;
@class SentryObjCEvent;
@class SentryObjCScope;
@class SentryObjCId;
@class SentryObjCFeedback;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCClient : NSObject

- (nullable instancetype)initWithOptions:(SentryObjCOptions *)options;

@property (nonatomic, readonly) BOOL isEnabled;
@property (nonatomic, strong) SentryObjCOptions *options;

- (SentryObjCId *)captureEvent:(SentryObjCEvent *)event NS_SWIFT_NAME(capture(event:));
- (SentryObjCId *)captureEvent:(SentryObjCEvent *)event
                     withScope:(SentryObjCScope *)scope NS_SWIFT_NAME(capture(event:scope:));

- (SentryObjCId *)captureError:(NSError *)error NS_SWIFT_NAME(capture(error:));
- (SentryObjCId *)captureError:(NSError *)error
                     withScope:(SentryObjCScope *)scope NS_SWIFT_NAME(capture(error:scope:));

- (SentryObjCId *)captureException:(NSException *)exception NS_SWIFT_NAME(capture(exception:));
- (SentryObjCId *)captureException:(NSException *)exception
                         withScope:(SentryObjCScope *)scope
    NS_SWIFT_NAME(capture(exception:scope:));

- (SentryObjCId *)captureMessage:(NSString *)message NS_SWIFT_NAME(capture(message:));
- (SentryObjCId *)captureMessage:(NSString *)message
                       withScope:(SentryObjCScope *)scope NS_SWIFT_NAME(capture(message:scope:));

- (void)captureFeedback:(SentryObjCFeedback *)feedback
              withScope:(SentryObjCScope *)scope NS_SWIFT_NAME(capture(feedback:scope:));

- (void)flush:(NSTimeInterval)timeout;
- (void)close;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
