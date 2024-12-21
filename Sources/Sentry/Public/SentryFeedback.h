#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentrySerializable.h>
#else
#    import <SentryWithoutUIKit/SentrySerializable.h>
#endif

typedef NS_ENUM(NSInteger, SentryFeedbackSource) {
    SentryFeedbackSourceWidget,
    SentryFeedbackSourceCustom
};

@class SentryAttachment;
@class SentryId;

NS_ASSUME_NONNULL_BEGIN

@interface SentryFeedback : NSObject <SentrySerializable>

- (instancetype)initWithMessage:(NSString *)message
                           name:(nullable NSString *)name
                          email:(nullable NSString *)email
                         source:(SentryFeedbackSource)source
              associatedEventId:(nullable NSString *)associatedEventId
              screenshotPNGData:(nullable NSData *)screenshot;

@property (nonatomic, strong) SentryId *eventId;

/**
 * - note: Currently there is only a single attachment possible, for the screenshot, of which there
 * can be only one.
 */
- (NSArray<SentryAttachment *> *)attachments;

@end

NS_ASSUME_NONNULL_END
