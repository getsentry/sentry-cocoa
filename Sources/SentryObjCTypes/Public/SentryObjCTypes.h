#import <Foundation/Foundation.h>

//! Project version number for SentryObjCTypes.
FOUNDATION_EXPORT double SentryObjCTypesVersionNumber;

//! Project version string for SentryObjCTypes.
FOUNDATION_EXPORT const unsigned char SentryObjCTypesVersionString[];

// Xcode frameworks expose sibling headers under `<SentryObjCTypes/...>`; SPM
// exposes them via -I on this target's publicHeadersPath (no framework wrapper),
// so we detect with __has_include and fall back to the quoted form.
#if __has_include(<SentryObjCTypes/SentryObjCAttributeContent.h>)
#    import <SentryObjCTypes/SentryObjCAttributeContent.h>
#    import <SentryObjCTypes/SentryObjCBridging.h>
#    import <SentryObjCTypes/SentryObjCMetric.h>
#    import <SentryObjCTypes/SentryObjCMetricValue.h>
#    import <SentryObjCTypes/SentryObjCRedactRegionType.h>
#    import <SentryObjCTypes/SentryObjCUnit.h>
#else
#    import "SentryObjCAttributeContent.h"
#    import "SentryObjCBridging.h"
#    import "SentryObjCMetric.h"
#    import "SentryObjCMetricValue.h"
#    import "SentryObjCRedactRegionType.h"
#    import "SentryObjCUnit.h"
#endif
