//
//  SentryIntegrationProtocol.h
//  Sentry
//
//  Created by Klemens Mantzos on 04.12.19.
//  Copyright © 2019 Sentry. All rights reserved.
//


#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryDefines.h>
#import <Sentry/SentryOptions.h>

#else
#import "SentryDefines.h"
#import "SentryOptions.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@protocol SentryIntegrationProtocol <NSObject>

/**
 * installs the integration and returns YES if no error(s) occured
 * NOTE: SentryOptions argument isn't always needed by the actual class implementing this protocol.
 */
- (BOOL)installWithOptions:(SentryOptions *)options;

/**
 * version of integration
 */
- (NSString *)version;

/**
 * name of integration
 * class name in most cases
 */
- (NSString *)name;

/**
 * combination of name and version.
 * supposed to be attached to the event so event processors to identify event data format.
 */
- (NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
