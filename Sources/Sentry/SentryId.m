#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryId.h>
#import <Sentry/SentryDefines.h>
#import <Sentry/SentrySerializable.h>
#else
#import "SentryId.h"
#import "SentryDefines.h"
#import "SentrySerializable.h"
#endif

@implementation SentryId

- (instancetype)initWithString:(NSString *)sentryIdString {
    self = [super init];
    if (self) {
//        self.type = type;
    }
    return self;
}

@end
