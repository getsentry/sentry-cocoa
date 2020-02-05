//
//  SentryUIKitMemoryWarningIntegration.h
//  Sentry
//
//  Created by Klemens Mantzos on 05.12.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SentryIntegrationProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/**
* Track memory pressure notifcation on UIApplications and send an event for it to Sentry.
*/
@interface SentryUIKitMemoryWarningIntegration : NSObject <SentryIntegrationProtocol>

@end

NS_ASSUME_NONNULL_END
