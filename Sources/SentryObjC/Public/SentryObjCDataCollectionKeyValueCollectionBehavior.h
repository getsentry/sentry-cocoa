#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDataCollectionKeyValueCollectionMode.h"
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDataCollectionKeyValueCollectionMode.h>
#    import <SentryObjC/SentryObjCDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/// Controls how key-value data (headers, cookies, query params) is collected and filtered.
///
/// Key names are always included regardless of mode. This type controls which
/// values are sent in plaintext vs. replaced with @c [Filtered].
///
/// DenyList and AllowList are mutually exclusive.
@interface SentryObjCDataCollectionKeyValueCollectionBehavior : NSObject
SENTRY_NO_INIT

/// The active collection mode.
@property (nonatomic, readonly) SentryObjCDataCollectionKeyValueCollectionMode mode;

/// Extra terms for the active mode. Empty for @c off.
@property (nonatomic, readonly, copy) NSArray<NSString *> *terms;

/// Do not collect this category at all — no keys or values are attached.
+ (instancetype)off;

/// Collect all values, scrubbing those matching the built-in sensitive denylist.
/// @param terms Extra terms to add to the built-in denylist.
+ (instancetype)denyListWithTerms:(NSArray<NSString *> *)terms;

/// Collect all values, scrubbing those matching the built-in sensitive denylist only.
+ (instancetype)denyList;

/// Only send values for explicitly listed keys; scrub all others.
/// @param terms The keys whose values should be sent in plaintext.
+ (instancetype)allowListWithTerms:(NSArray<NSString *> *)terms;

@end

NS_ASSUME_NONNULL_END
