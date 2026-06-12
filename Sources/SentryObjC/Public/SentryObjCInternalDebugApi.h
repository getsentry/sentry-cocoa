#import <Foundation/Foundation.h>

@class SentryObjCDebugMeta;

NS_ASSUME_NONNULL_BEGIN

/// Debug image APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalDebugApi : NSObject

/// All debug images currently loaded by the process.
@property (nonatomic, readonly, copy) NSArray<SentryObjCDebugMeta *> *images;

/// Debug images for the given raw memory addresses.
- (NSArray<SentryObjCDebugMeta *> *)imagesForAddresses:(NSArray<NSNumber *> *)addresses;

@end

NS_ASSUME_NONNULL_END
