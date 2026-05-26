#import "SentryObjCFeedbackSource.h"
#import <Foundation/Foundation.h>

@class SentryObjCId;
@class SentryObjCAttachment;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCFeedback : NSObject

@property (nonatomic, readonly, copy) NSString *message;
@property (nonatomic, readonly, copy, nullable) NSString *name;
@property (nonatomic, readonly, copy, nullable) NSString *email;
@property (nonatomic, readonly) SentryObjCFeedbackSource source;
@property (nonatomic, readonly, strong) SentryObjCId *eventId;
@property (nonatomic, readonly, strong, nullable) SentryObjCId *associatedEventId;
@property (nonatomic, readonly, strong, nullable) NSArray<SentryObjCAttachment *> *attachments;

- (instancetype)initWithMessage:(NSString *)message
                           name:(nullable NSString *)name
                          email:(nullable NSString *)email
                         source:(SentryObjCFeedbackSource)source
              associatedEventId:(nullable SentryObjCId *)associatedEventId
                    attachments:(nullable NSArray<SentryObjCAttachment *> *)attachments;

@end

NS_ASSUME_NONNULL_END
