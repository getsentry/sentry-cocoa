#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SentryObjCRedactRegionType) {
    SentryObjCRedactRegionTypeRedact = 0,
    SentryObjCRedactRegionTypeClipOut,
    SentryObjCRedactRegionTypeClipBegin,
    SentryObjCRedactRegionTypeClipEnd,
    SentryObjCRedactRegionTypeRedactSwiftUI
};
