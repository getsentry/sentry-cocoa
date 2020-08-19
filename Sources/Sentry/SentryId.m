#import "SentryId.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const emptyUUIDString = @"00000000-0000-0000-0000-000000000000";

@interface
SentryId ()

@property (nonatomic, strong) NSUUID *uuid;

@end

@implementation SentryId

static SentryId *_empty = nil;

- (instancetype)init
{
    return [self initWithUUID:[NSUUID UUID]];
}

- (instancetype)initWithUUID:(NSUUID *)uuid
{
    if (self = [super init]) {
        self.uuid = uuid;
    }
    return self;
}

- (instancetype)initWithUUIDString:(NSString *)string
{
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:string];

    if (nil != uuid) {
        return [self initWithUUID:uuid];
    } else {
        return [self initWithUUIDString:emptyUUIDString];
    }
}

- (NSString *)sentryIdString;
{
    return self.uuid.UUIDString;
}

- (NSString *)description
{
    return [self sentryIdString];
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if ([self class] != [object class]) {
        return NO;
    }

    SentryId *otherSentryID = (SentryId *)object;

    return [self.uuid isEqual:otherSentryID.uuid];
}

- (NSUInteger)hash
{
    return [self.uuid hash];
}

+ (SentryId *)empty
{
    if (nil == _empty) {
        _empty = [[SentryId alloc] initWithUUIDString:emptyUUIDString];
    }
    return _empty;
}

@end

NS_ASSUME_NONNULL_END
