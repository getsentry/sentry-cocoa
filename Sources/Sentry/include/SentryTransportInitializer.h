//
//  SentryTransportInitializer.h
//  SentryTests
//
//  Created by Philipp Hofmann on 08.04.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryTransport.h>
#import <Sentry/SentryOptions.h>

#else
#import "SentryTransport.h"
#import "SentryOptions.h"
#endif

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TransportInitializer)
@interface SentryTransportInitializer : NSObject

+ (id<SentryTransport>_Nonnull) initTransport:(SentryOptions *) options
                            sentryFileManager:(SentryFileManager *)sentryFileManager;

@end

NS_ASSUME_NONNULL_END
