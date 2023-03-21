//
//  SentryBreadcrumb+Private.h
//  Sentry
//
//  Created by Denis Andrašec on 21.03.23.
//  Copyright © 2023 Sentry. All rights reserved.
//

#import "SentryDefines.h"
#import "SentrySerializable.h"
#import <SentryBreadcrumb.h>

@interface
SentryBreadcrumb (Private)

/**
 * Initializes a SentryBreadcrumb from a JSON object.
 * @param dictionary The dictionary containing breadcrumb data.
 * @return The SentryBreadcrumb or nil if initializing with the dictionary results in an error.
 */
- (nullable instancetype)initWithDictionary:(NSDictionary *_Nullable)dictionary;
@end
