//
//  SentrySwift.h
//  SentrySwift
//
//  Created by Josh Holtz on 12/16/15.
//
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
@import KSCrash;
#endif

//! Project version number for SentrySwift.
FOUNDATION_EXPORT double SentrySwiftVersionNumber;

//! Project version string for SentrySwift.
FOUNDATION_EXPORT const unsigned char SentrySwiftVersionString[];

