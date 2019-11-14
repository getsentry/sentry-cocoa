//
//  SentryHub.h
//  Sentry
//
//  Created by Klemens Mantzos on 11.11.19.
//  Copyright © 2019 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryClient.h>
#import <Sentry/SentryBreadcrumb.h>
#import <Sentry/SentryDefines.h>
#import <Sentry/SentryEvent.h>
#else
#import "SentryClient.h"
#import "SentryBreadcrumb.h"
#import "SentryDefines.h"
#import "SentryEvent.h"
#endif

NS_ASSUME_NONNULL_BEGIN
@interface SentryHub : NSObject

+ (instancetype)defaultHub;

/**
 creates new hub with given client
 TODO(fetzig): add scope as soon as detached from client
 */
- (instancetype)initWithClient:(SentryClient *)aClient;

/**
 creates a new hub by cloning the top stack of another hub
 TODO(fetzig): check this in sentry-python a.s.o.
 */
//- (instancetype)initFromTop:(SentryHub *)hub;

/**
 returns current (threads) hub
 TODO(fetzig): think we don't need this in cocoa, check if this ("thread bound hub model")
 */
// + (SentryHub *)currentHub;

/**
 returns main (threads) hub
 TODO(fetzig): think we don't need this in cocoa, check if this ("thread bound hub model")
 */
// + (SentryHub *)mainHub;

/**
 Capture message / exception call into capture event
 TODO(fetzig): As an additional argument it also takes a Hint.
 */
- (void)captureEvent:(SentryEvent *)event;

// TODO(fetzig): add those once whe have scope
//- Hub::push_scope(): Pushes a new scope layer that inherits the previous data. This should return a disposable or stack guard for languages where it makes sense. When the “internally scoped hub” concurrency model is used calls to this are often necessary as otherwise a scope might be accidentally incorrectly shared.
//- `Hub::with_scope(callback)` (optional): In Python this could be a context manager, in Ruby a block function. Pushes and pops a scope for integration work.
//- `Hub::pop_scope()` (optional): Only exists in languages without better resource management. Better to have this function on a return value of `push_scope` or to use `with_scope`. This is also sometimes called `pop_scope_unsafe` to indicate that this method should not be used directly.
//- `Hub::configure_scope(callback)`: Invokes the callback with a mutable reference to the scope for modifications This can also be a `with` statement in languages that have it (Python).

/**
 Adds a breadcrumb to the current client.
 TODO(fetzig): add it to scope instead, once we have it.
 */
- (void)addBreadcrumb:(SentryBreadcrumb *)crumb;

/**
 returns current client (or none)
 */
- (SentryClient * _Nullable)getClient;

//- `Hub::bind_client(new_client)`: Binds a different client to the hub. If the hub is also the owner of the client that was created by `init` it needs to keep a reference to it still if the hub is the object responsible for disposing it.
- (void)bindClient:(SentryClient *)aClient;

//- `Hub::unbind_client()` (optional): Optional way to unbind for languages where `bind_client` does not accept nullables.
- (void)unbindClient;

//- `Hub::last_event_id()`: Should return the last event ID emitted by the current scope. This is for instance used to implement user feedback dialogs.
//- `Hub::run(hub, callback)` `hub.run(callback)`, `run_in_hub(hub, callback)` (optional): Runs a callback with the hub bound as the current hub.

/**
 resets hub by removing current client
 TODO(fetzig): currently used by unit tests only. should be removed after "unified api hub" is fully implemented.
 */
- (void)reset;

@end

NS_ASSUME_NONNULL_END
