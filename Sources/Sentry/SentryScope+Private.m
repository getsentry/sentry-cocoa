//
//  SentryScope+Private.m
//  Sentry
//
//  Created by Daniel Griesser on 25.02.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

#import "SentryScope+Private.h"
#import <objc/runtime.h>

@implementation SentryScope (Private)

@dynamic listeners;

- (NSMutableArray<SentryScopeListener> *)listeners{
    return objc_getAssociatedObject(self, @selector(listeners));
}

- (void)setListeners:(NSMutableArray<SentryScopeListener> *)listeners {
    objc_setAssociatedObject(self, @selector(listeners), listeners, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)addScopeListener:(SentryScopeListener)listener; {
    [self.listeners addObject:listener];
}

- (void)notifyListeners {
    for (SentryScopeListener listener in self.listeners) {
        listener(self);
    }
}

@end
