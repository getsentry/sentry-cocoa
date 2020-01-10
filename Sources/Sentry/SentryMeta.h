//
//  SentryMeta.h
//  Sentry
//
//  Created by Klemens Mantzos on 08.01.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryMeta : NSObject

/**
 * Return a version string e.g: 1.2.3 (3)
 */
@property(nonatomic, class, readonly, copy) NSString *versionString;

/**
 * Return a string sentry-cocoa
 */
@property(nonatomic, class, readonly, copy) NSString *sdkName;

@end

NS_ASSUME_NONNULL_END
