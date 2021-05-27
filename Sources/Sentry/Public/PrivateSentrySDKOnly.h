#import <Foundation/Foundation.h>

#import "SentryDefines.h"

@class SentryEnvelope, SentryDebugMeta;

NS_ASSUME_NONNULL_BEGIN

/**
 * ATTENTION: This class is reserved for hybrid SDKs. Methods may be changed, renamed or removed
 * without notice. If you want to use one of these methods here please open up an issue and let us
 * now.
 *
 * The name of this class is supposed to be a bit weird and ugly. The name starts with private on
 * purpose so users don't see it in code completion when typing Sentry. We also add only at the end
 * to make it more obvious you shouldn't use it.
 */
@interface PrivateSentrySDKOnly : NSObject

/**
 * For storing an envelope synchronously to disk.
 */
+ (void)storeEnvelope:(SentryEnvelope *)envelope;

+ (void)captureEnvelope:(SentryEnvelope *)envelope;

/**
 * Create an envelope from NSData. Needed for example by Flutter.
 */
+ (nullable SentryEnvelope *)envelopeWithData:(NSData *)data;

/**
 * Returns the current list of debug images. Be aware that the SentryDebugMeta is actually
 * describing a debug image. This class should be renamed to SentryDebugImage in a future version.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImages;

@end

NS_ASSUME_NONNULL_END
