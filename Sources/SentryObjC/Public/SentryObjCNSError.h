#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"
#import "SentryObjCSerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Sentry representation of an NSError for serialization.
 *
 * @see SentryMechanismContext
 */
@interface SentryNSError : NSObject <SentrySerializable>

SENTRY_NO_INIT

@property (nonatomic, copy) NSString *domain;
@property (nonatomic, assign) NSInteger code;

- (instancetype)initWithDomain:(NSString *)domain code:(NSInteger)code;

@end

NS_ASSUME_NONNULL_END
