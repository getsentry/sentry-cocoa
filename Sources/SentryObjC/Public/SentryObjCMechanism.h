#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"
#import "SentryObjCSerializable.h"

@class SentryMechanismContext;

NS_ASSUME_NONNULL_BEGIN

/**
 * Error mechanism describing how the error was produced.
 *
 * @see SentryException
 */
@interface SentryMechanism : NSObject <SentrySerializable>

SENTRY_NO_INIT

@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy, nullable) NSString *desc;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *data;
@property (nonatomic, copy, nullable) NSNumber *handled;
@property (nonatomic, copy, nullable) NSNumber *synthetic;
@property (nonatomic, copy, nullable) NSString *helpLink;
@property (nullable, nonatomic, strong) SentryMechanismContext *meta;

- (instancetype)initWithType:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
