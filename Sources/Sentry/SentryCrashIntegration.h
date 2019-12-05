//
//  SentryCrashIntegration.h
//  Sentry
//
//  Created by Klemens Mantzos on 04.12.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryIntegrationProtocol.h>

#else
#import "SentryIntegrationProtocol.h"
#endif


NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashIntegration : NSObject <SentryIntegrationProtocol>

@end

NS_ASSUME_NONNULL_END
