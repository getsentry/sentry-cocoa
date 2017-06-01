//
//  SentryClient+Internal.h
//  Sentry
//
//  Created by Daniel Griesser on 01/06/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//


#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentryClient.h>

#else
#import "SentryClient.h"
#endif

@interface SentryClient ()

@property(nonatomic, strong) NSArray<SentryThread *> *_Nullable _snapshotThreads;

@end
