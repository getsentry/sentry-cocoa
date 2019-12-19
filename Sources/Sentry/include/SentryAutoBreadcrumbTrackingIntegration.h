//
//  SentryAutoBreadcrumbTrackingIntegration.h
//  Sentry
//
//  Created by Klemens Mantzos on 05.12.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryAutoBreadcrumbTrackingIntegration.h>

#else
#import "SentryAutoBreadcrumbTrackingIntegration.h"
#endif

NS_ASSUME_NONNULL_BEGIN

/**
* This automatically adds breadcrumbs for different user actions.
*/
@interface SentryAutoBreadcrumbTrackingIntegration : NSObject

@end

NS_ASSUME_NONNULL_END
