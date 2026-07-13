#import <Foundation/Foundation.h>

/// Modes for key-value data collection filtering.
typedef NS_ENUM(NSInteger, SentryObjCDataCollectionKeyValueCollectionMode) {
    /// Do not collect this category at all.
    SentryObjCDataCollectionKeyValueCollectionModeOff = 0,
    /// Collect all values, scrubbing those matching the built-in sensitive denylist.
    SentryObjCDataCollectionKeyValueCollectionModeDenyList,
    /// Only send values for explicitly listed keys; scrub all others.
    SentryObjCDataCollectionKeyValueCollectionModeAllowList
};
