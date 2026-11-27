#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCLevel.h"
#else
#    import <SentryObjC/SentryObjCLevel.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a breadcrumb, a trail of events leading up to an error or crash.
 */
@interface SentryObjCBreadcrumb : NSObject

/// Level of breadcrumb.
@property (nonatomic) SentryObjCLevel level;

/// Category of breadcrumb, can be any string.
@property (nonatomic, copy) NSString *category;

/// @c NSDate when the breadcrumb happened.
@property (nonatomic, strong, nullable) NSDate *timestamp;

/**
 * Type of breadcrumb, can be e.g.: http, empty, user, navigation.
 * This will be used as icon of the breadcrumb.
 */
@property (nonatomic, copy, nullable) NSString *type;

/// Message for the breadcrumb.
@property (nonatomic, copy, nullable) NSString *message;

/**
 * Origin of the breadcrumb that is used to identify source of the breadcrumb.
 * For example hybrid SDKs can identify native breadcrumbs from JS or Flutter.
 */
@property (nonatomic, copy, nullable) NSString *origin;

/// Arbitrary additional data sent with the breadcrumb. Use @c setDataValue:forKey: to update it.
@property (nonatomic, copy, readonly, nullable) NSDictionary<NSString *, id> *data;

/**
 * Sets a single value in the breadcrumb's @c data dictionary for the given key.
 * Passing @c nil as the value removes the key.
 * @param value The value to store, or @c nil to remove the key.
 * @param key The key to set.
 */
- (void)setDataValue:(nullable id)value forKey:(NSString *)key;

/**
 * Initializer for @c SentryObjCBreadcrumb.
 * @param level The severity level of the breadcrumb.
 * @param category The category string for the breadcrumb.
 */
- (instancetype)initWithLevel:(SentryObjCLevel)level category:(NSString *)category;
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
