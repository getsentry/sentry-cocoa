#import "SentryEventSwiftHelper.h"
#import "SentryEvent.h"
#import "SentrySwift.h"

@implementation SentryEventSwiftHelper

+ (void)setEventIdString:(NSString *)idString event:(SentryEvent *)event
{
    event.eventId = [[SentryId alloc] initWithUUIDString:idString];
}

+ (NSString *)getEventIdString:(SentryEvent *)event
{
    return event.eventId.sentryIdString;
}

@end
