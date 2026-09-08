#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

@class SentryObjCAttachment;

NS_ASSUME_NONNULL_BEGIN

/**
 * Provides metadata about the origin of an event or breadcrumb.
 *
 * A hint flows alongside the event through the capture pipeline, giving callbacks access to the
 * raw source material that produced the event, such as the original @c NSError or @c NSException,
 * and the list of attachments that will be sent with it.
 */
@interface SentryObjCHint : NSObject

/// The original @c NSError that triggered the event capture, if any.
@property (nonatomic, strong, nullable) NSError *originalError;

/// The original @c NSException that triggered the event capture, if any.
@property (nonatomic, strong, nullable) NSException *originalException;

/**
 * The attachments that will be sent alongside the event.
 *
 * Before @c beforeSendWithHint is invoked, the SDK pre-populates this list with the attachments
 * that will be sent with the event, such as the scope's attachments. The list left in the hint
 * when the callback returns is what the SDK sends, so attachments can be both added and removed
 * in the callback.
 */
@property (nonatomic, copy) NSArray<SentryObjCAttachment *> *attachments;

- (nonnull instancetype)init;

/// Creates a hint pre-populated with the original error.
- (nonnull instancetype)initWithError:(nonnull NSError *)error;

/// Creates a hint pre-populated with the original exception.
- (nonnull instancetype)initWithException:(nonnull NSException *)exception;

/**
 * Stores an arbitrary value in the hint, accessible by key.
 * @param value The value to store.
 * @param key The key to associate with the value.
 */
- (void)setHintValue:(nullable id)value forKey:(nonnull NSString *)key;

/**
 * Returns the value associated with the given key, or @c nil if not set.
 * @param key The key to look up.
 */
- (nullable id)hintValueForKey:(nonnull NSString *)key;

/**
 * Removes the value for the given key.
 * @param key The key to remove.
 */
- (void)removeHintValueForKey:(nonnull NSString *)key;

@end

NS_ASSUME_NONNULL_END
