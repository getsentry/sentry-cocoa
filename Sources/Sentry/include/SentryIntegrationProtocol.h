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
 * installs the integration and returns YES if successful.
 */
- (void)installWithOptions:(SentryOptions *)options;

@end

NS_ASSUME_NONNULL_END
