#import <Foundation/Foundation.h>

@class SentryEnvelope, SentryEvent, SentrySession, SentryUserFeedback;

NS_ASSUME_NONNULL_BEGIN

// TODO: align with unified SDK api
NS_SWIFT_NAME(Transport)
@protocol SentryTransport <NSObject>

- (void)sendEvent:(SentryEvent *)event NS_SWIFT_NAME(send(event:));

- (void)sendEvent:(SentryEvent *)event withSession:(SentrySession *)session;

- (void)sendUserFeedback:(SentryUserFeedback *)userFeedback NS_SWIFT_NAME(send(userFeedback:));

- (void)sendEnvelope:(SentryEnvelope *)envelope NS_SWIFT_NAME(send(envelope:));

@end

NS_ASSUME_NONNULL_END
