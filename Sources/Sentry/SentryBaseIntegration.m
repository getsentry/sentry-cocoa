#import "SentryBaseIntegration.h"
#import "SentryLog.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryOptionWithDescription
- (instancetype)initWithOption:(BOOL)option log:(NSString *)log
{
    if (self = [super init]) {
        self.option = option;
        self.log = log;
    }
    return self;
}
- (instancetype)initWithOption:(BOOL)option optionName:(NSString *)optionName
{
    if (self = [super init]) {
        self.option = option;
        self.optionName = optionName;
    }
    return self;
}
@end

@implementation SentryBaseIntegration

- (NSString *)integrationName
{
    return NSStringFromClass([self classForCoder]);
}

- (BOOL)isEnabled:(BOOL)option
{
    return [self shouldBeEnabled:@[ @(option) ]];
}

- (BOOL)shouldBeEnabled:(NSArray *)options
{
    for (id option in options) {
        if ([option isKindOfClass:[NSNumber class]]) {
            NSNumber *castedOption = option;
            if (![castedOption boolValue]) {
                [SentryLog logWithMessage:[NSString stringWithFormat:@"Not going to enable %@",
                                                    [self integrationName]]
                                 andLevel:kSentryLevelDebug];
                return NO;
            }
        }

        if ([option isKindOfClass:[SentryOptionWithDescription class]]) {
            SentryOptionWithDescription *castedOption = option;
            if (!castedOption.option) {
                if (castedOption.optionName != nil) {
                    [SentryLog
                        logWithMessage:
                            [NSString
                                stringWithFormat:@"Not going to enable %@ because %@ is disabled",
                                [self integrationName], castedOption.optionName]
                              andLevel:kSentryLevelDebug];
                } else {
                    [SentryLog logWithMessage:castedOption.log andLevel:kSentryLevelDebug];
                }
                return NO;
            }
        }
    }

    return YES;
}

@end

NS_ASSUME_NONNULL_END
