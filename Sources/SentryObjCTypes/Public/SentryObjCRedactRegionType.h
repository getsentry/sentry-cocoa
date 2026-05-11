#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Defines how a region should be handled during session replay redaction.
 */
typedef NSString *SentryObjCRedactRegionType NS_STRING_ENUM;

FOUNDATION_EXPORT SentryObjCRedactRegionType const SentryObjCRedactRegionTypeRedact;
FOUNDATION_EXPORT SentryObjCRedactRegionType const SentryObjCRedactRegionTypeClipOut;
FOUNDATION_EXPORT SentryObjCRedactRegionType const SentryObjCRedactRegionTypeClipBegin;
FOUNDATION_EXPORT SentryObjCRedactRegionType const SentryObjCRedactRegionTypeClipEnd;
FOUNDATION_EXPORT SentryObjCRedactRegionType const SentryObjCRedactRegionTypeRedactSwiftUI;

NS_ASSUME_NONNULL_END
