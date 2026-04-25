#import <Foundation/Foundation.h>

//! Project version number for SentryObjCTypes.
FOUNDATION_EXPORT double SentryObjCTypesVersionNumber;

//! Project version string for SentryObjCTypes.
FOUNDATION_EXPORT const unsigned char SentryObjCTypesVersionString[];

// Sibling headers imported with quoted form. Xcode frameworks prefer angle-bracket
// imports (`<SentryObjCTypes/...>`) in umbrella headers, but SPM C targets don't
// expose that layout — the headers are co-located without a framework wrapper, so
// quoted form is the only form that resolves in both contexts.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wquoted-include-in-framework-header"
#import "SentryObjCAttributeContent.h"
#import "SentryObjCMetric.h"
#import "SentryObjCMetricValue.h"
#import "SentryObjCRedactRegionType.h"
#import "SentryObjCUnit.h"
#pragma clang diagnostic pop
