#import "SentryUserFeedback.h"
#import "SentrySwift.h"
#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    /** A user feedback attached to a transaction or error event. */
    kSentryUserFeedbackTypeAttached,

    /** A user feedback sent as its own event independent of any other event. */
    kSentryUserFeedbackTypeStandalone,
} SentryUserFeedbackType;

@implementation SentryUserFeedback {
    SentryUserFeedbackType _type;
}

- (instancetype)init
{
    if (self = [super init]) {
        _type = kSentryUserFeedbackTypeStandalone;
        _eventId = [[SentryId alloc] init];
    }
    return self;
}

- (instancetype)initWithEventId:(SentryId *)eventId
{
    if (self = [super init]) {
        _eventId = eventId;
        _email = @"";
        _name = @"";
        _comments = @"";
        _type = kSentryUserFeedbackTypeAttached;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    switch (_type) {
    case kSentryUserFeedbackTypeAttached:
        return @{
            @"event_id" : self.eventId.sentryIdString,
            @"email" : self.email,
            @"name" : self.name,
            @"comments" : self.comments
        };
    case kSentryUserFeedbackTypeStandalone:
        return @{

        };
    }
}

@end
