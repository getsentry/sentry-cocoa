#import "SentryFeedback.h"
#import "SentryAttachment.h"
#import "SentrySwift.h"

@interface SentryFeedback ()

@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, copy, nullable) NSString *email;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) SentryFeedbackSource source;
@property (nonatomic, copy, nullable) NSData *screenshotPNGData;
@property (nonatomic, copy, nullable) NSString *associatedEventId;

@end

@implementation SentryFeedback

- (instancetype)initWithMessage:(NSString *)message
                           name:(nullable NSString *)name
                          email:(nullable NSString *)email
                         source:(SentryFeedbackSource)source
              associatedEventId:(nullable NSString *)associatedEventId
              screenshotPNGData:(nullable NSData *)screenshotPNGData
{
    self = [super init];
    if (self) {
        self.eventId = [[SentryId alloc] init];
        self.name = name;
        self.email = email;
        self.message = message;
        self.source = source;
        self.associatedEventId = associatedEventId;
        self.screenshotPNGData = screenshotPNGData;
    }
    return self;
}

- (NSDictionary *)serialize
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"message"] = self.message;
    if (self.name) {
        dict[@"name"] = self.name;
    }
    if (self.email) {
        dict[@"contact_email"] = self.email;
    }
    if (self.associatedEventId) {
        dict[@"associated_event_id"] = self.associatedEventId;
    }

    switch (self.source) {
    case SentryFeedbackSourceWidget:
        dict[@"source"] = @"widget";
        break;
    case SentryFeedbackSourceCustom:
        dict[@"source"] = @"custom";
        break;
    }

    return dict;
}

- (NSArray<SentryAttachment *> *)attachments
{
    NSMutableArray<SentryAttachment *> *items = [NSMutableArray array];
    if (self.screenshotPNGData) {
        SentryAttachment *attachment = [[SentryAttachment alloc] initWithData:self.screenshotPNGData
                                                                     filename:@"screenshot.png"
                                                                  contentType:@"application/png"];
        [items addObject:attachment];
    }
    return items;
}

@end
