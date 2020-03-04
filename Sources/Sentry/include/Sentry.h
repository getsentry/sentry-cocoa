//
//  Sentry.h
//  Sentry
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for Sentry.
FOUNDATION_EXPORT double SentryVersionNumber;

//! Project version string for Sentry.
FOUNDATION_EXPORT const unsigned char SentryVersionString[];

#if __has_include(<Sentry/Sentry.h>)

#import <Sentry/SentrySerialization.h>
#import <Sentry/SentryEnvelope.h>
#import <Sentry/SentryCrash.h>
#import <Sentry/SentrySDK.h>
#import <Sentry/SentryHub.h>
#import <Sentry/SentryClient.h>
#import <Sentry/SentrySwizzle.h>

#import <Sentry/SentryNSURLRequest.h>

#import <Sentry/SentrySerializable.h>

#import <Sentry/SentryEvent.h>
#import <Sentry/SentryScope.h>
#import <Sentry/SentryThread.h> 
#import <Sentry/SentryMechanism.h>
#import <Sentry/SentryException.h>
#import <Sentry/SentryStacktrace.h>
#import <Sentry/SentryFrame.h>
#import <Sentry/SentryUser.h>
#import <Sentry/SentryDebugMeta.h>
#import <Sentry/SentryBreadcrumb.h>
#import <Sentry/SentryTransport.h>

#else

#import "SentrySerialization.h"
#import "SentryEnvelope.h"
#import "SentryCrash.h"
#import "SentrySDK.h"
#import "SentryHub.h"
#import "SentryClient.h"
#import "SentrySwizzle.h"

#import "SentryNSURLRequest.h"

#import "SentrySerializable.h"

#import "SentryEvent.h"
#import "SentryScope.h"
#import "SentryThread.h"
#import "SentryMechanism.h"
#import "SentryException.h"
#import "SentryStacktrace.h"
#import "SentryFrame.h"
#import "SentryUser.h"
#import "SentryDebugMeta.h"
#import "SentryBreadcrumb.h"
#import "SentryTransport.h"

#endif
