#import <Foundation/Foundation.h>

@class SOCSentryOptions;
@class SOCSentryEvent;
@class SOCSentryId;
@class SOCSentryScope;
@class SOCSentryFeedback;

NS_ASSUME_NONNULL_BEGIN

/// The Sentry client is responsible for capturing events and sending them to Sentry.
@interface SOCSentryClient : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (nullable instancetype)initWithOptions:(SOCSentryOptions *)options;

@property (nonatomic, readonly) BOOL isEnabled;
@property (nonatomic, strong) SOCSentryOptions *options;

- (SOCSentryId *)captureEvent:(SOCSentryEvent *)event;
- (SOCSentryId *)captureEvent:(SOCSentryEvent *)event withScope:(SOCSentryScope *)scope;
- (SOCSentryId *)captureError:(NSError *)error;
- (SOCSentryId *)captureError:(NSError *)error withScope:(SOCSentryScope *)scope;
- (SOCSentryId *)captureException:(NSException *)exception;
- (SOCSentryId *)captureException:(NSException *)exception withScope:(SOCSentryScope *)scope;
- (SOCSentryId *)captureMessage:(NSString *)message;
- (SOCSentryId *)captureMessage:(NSString *)message withScope:(SOCSentryScope *)scope;
- (void)captureFeedback:(SOCSentryFeedback *)feedback withScope:(SOCSentryScope *)scope;
- (void)flush:(NSTimeInterval)timeout;
- (void)close;

@end

NS_ASSUME_NONNULL_END
