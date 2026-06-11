#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SentryObjCSwizzleMode) {
    SentryObjCSwizzleModeAlways = 0,
    SentryObjCSwizzleModeOncePerClass = 1,
    SentryObjCSwizzleModeOncePerClassAndSuperclasses = 2
};

/// Stable swizzling API for hybrid SDKs.
/// Replaces direct import of SentrySwizzle.h and its macro-based API.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalSwizzleApi : NSObject

/// Swizzle an instance method. The factory block receives a block that
/// returns the original IMP; return a new block matching the method signature.
- (BOOL)swizzleInstanceMethod:(SEL)selector
                      inClass:(Class)cls
                newImpFactory:(id _Nonnull (^)(IMP (^)(void)))factoryBlock
                         mode:(SentryObjCSwizzleMode)mode
                          key:(const void *)key;

@end

NS_ASSUME_NONNULL_END
