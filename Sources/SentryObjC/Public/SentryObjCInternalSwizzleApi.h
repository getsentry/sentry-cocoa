#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/// Swizzle mode controlling when a method is swizzled.
typedef NS_ENUM(NSInteger, SentryObjCSwizzleMode) {
    /// Swizzle every time, even if already swizzled.
    SentryObjCSwizzleModeAlways = 0,
    /// Swizzle only once per class (recommended default).
    SentryObjCSwizzleModeOncePerClass = 1,
    /// Swizzle only if neither this class nor any superclass was swizzled.
    SentryObjCSwizzleModeOncePerClassAndSuperclasses = 2,
};

/// Method swizzling APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalSwizzleApi : NSObject
SENTRY_NO_INIT

/// Swizzles an instance method on the given class.
///
/// The factory block receives a block that returns the original implementation.
/// The factory must return a new block that becomes the replacement implementation.
///
/// @param selector The selector of the method to swizzle.
/// @param classToSwizzle The class containing the method to swizzle.
/// @param mode The swizzle mode.
/// @param key A unique key to identify this swizzle operation.
/// @param factory A block that receives the original implementation provider and returns
///   the replacement implementation block.
/// @return @c YES if successfully swizzled, @c NO if already done for this key and class.
- (BOOL)swizzleInstanceMethod:(SEL)selector
                      inClass:(Class)classToSwizzle
                         mode:(SentryObjCSwizzleMode)mode
                          key:(const void *)key
                newImpFactory:(id (^)(IMP(NS_NOESCAPE ^)(void)))factory;

@end

NS_ASSUME_NONNULL_END
