#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Defines how a region should be handled during session replay redaction.
 */
typedef NSString *SentryRedactRegionType NS_STRING_ENUM;

FOUNDATION_EXPORT SentryRedactRegionType const SentryRedactRegionTypeRedact;
FOUNDATION_EXPORT SentryRedactRegionType const SentryRedactRegionTypeClipOut;
FOUNDATION_EXPORT SentryRedactRegionType const SentryRedactRegionTypeClipBegin;
FOUNDATION_EXPORT SentryRedactRegionType const SentryRedactRegionTypeClipEnd;
FOUNDATION_EXPORT SentryRedactRegionType const SentryRedactRegionTypeRedactSwiftUI;

NS_ASSUME_NONNULL_END
