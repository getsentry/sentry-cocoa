#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryDescriptor;

NSString *sentry_getClassDescription(Class aClass);

NSString *sentry_getObjectClassDescription(NSObject *object);

NSString *sentry_getDescription(NSObject *object);

void sentry_setGlobalDescriptor(SentryDescriptor *descriptor);

@interface SentryDescriptor : NSObject

- (NSString *)getClassDescription:(Class)aClass;

- (NSString *)getObjectClassDescription:(NSObject *)object;

- (NSString *)getDescription:(NSObject *)object;

@end

NS_ASSUME_NONNULL_END
