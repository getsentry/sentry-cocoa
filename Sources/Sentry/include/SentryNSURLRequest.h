//
//  SentryNSURLRequest.h
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryDsn, SentryEvent;

@interface SentryNSURLRequest : NSMutableURLRequest

- (instancetype)initStoreRequestWithDsn:(SentryDsn *)dsn andEvent:(SentryEvent *)event;

@end

NS_ASSUME_NONNULL_END
