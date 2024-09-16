#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#    import <Sentry/SentrySerializable.h>
#else
#    import <SentryWithoutUIKit/SentryDefines.h>
#    import <SentryWithoutUIKit/SentrySerializable.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryId;

/**
 * Adds additional information about what happened to an event.
 */
NS_SWIFT_NAME(UserFeedback)
@interface SentryUserFeedback : NSObject <SentrySerializable>
SENTRY_NO_INIT

/**
 * Initializes SentryUserFeedback and sets the required eventId.
 * @param eventId The eventId of the event to which the user feedback is associated.
 */
- (instancetype)initWithEventId:(SentryId *)eventId;

/**
 * The eventId of the event to which the user feedback is associated.
 */
@property (readonly, nonatomic, strong) SentryId *eventId;

/**
 * The name of the user.
 */
@property (nonatomic, copy) NSString *name;

/**
 * The email of the user.
 */
@property (nonatomic, copy) NSString *email;

/**
 * Comments of the user about what happened.
 */
@property (nonatomic, copy) NSString *comments;

@end

NS_ASSUME_NONNULL_END
