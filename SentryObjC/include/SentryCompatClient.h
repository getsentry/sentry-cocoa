#import <Foundation/Foundation.h>

@class SentryCompatOptions;
@class SentryCompatEvent;
@class SentryCompatId;
@class SentryCompatScope;
@class SentryCompatFeedback;

NS_ASSUME_NONNULL_BEGIN

/// The Sentry client is responsible for capturing events and sending them to Sentry.
@interface SentryCompatClient : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (nullable instancetype)initWithOptions:(SentryCompatOptions *)options;

@property (nonatomic, readonly) BOOL isEnabled;
@property (nonatomic, strong) SentryCompatOptions *options;

- (SentryCompatId *)captureEvent:(SentryCompatEvent *)event;
- (SentryCompatId *)captureEvent:(SentryCompatEvent *)event withScope:(SentryCompatScope *)scope;
- (SentryCompatId *)captureError:(NSError *)error;
- (SentryCompatId *)captureError:(NSError *)error withScope:(SentryCompatScope *)scope;
- (SentryCompatId *)captureException:(NSException *)exception;
- (SentryCompatId *)captureException:(NSException *)exception withScope:(SentryCompatScope *)scope;
- (SentryCompatId *)captureMessage:(NSString *)message;
- (SentryCompatId *)captureMessage:(NSString *)message withScope:(SentryCompatScope *)scope;
- (void)captureFeedback:(SentryCompatFeedback *)feedback withScope:(SentryCompatScope *)scope;
- (void)flush:(NSTimeInterval)timeout;
- (void)close;

@end

NS_ASSUME_NONNULL_END
