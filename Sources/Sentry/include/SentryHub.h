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
- (void)initWithOptions:(NSDictionary<NSString *,id> *)options;

// keeps a stack of client and scope

//- `Hub::new(client, scope)`: Creates a new hub with the given client and scope. The client can be reused between hubs. The scope should be owned by the hub (make a clone if necessary)

//- `Hub::new_from_top(hub)` / alternatively native constructor overloads: Creates a new hub by cloning the top stack of another hub.

//- `get_current_hub()` / `Hub::current()` / `Hub::get_current()`: Global function or static function to return the current (threads) hub

//- `get_main_hub()` / `Hub::main()` / `Hub::get_main()`: In languages where the main thread is special (“Thread bound hub” model) this returns the main thread’s hub instead of the current thread’s hub. This might not exist in all languages.

//- `Hub::capture_event` / `Hub::capture_message` / `Hub::capture_exception` Capture message / exception call into capture event. `capture_event` merges the event passed with the scope data and dispatches to the client. As an additional argument it also takes a Hint.

- (void)captureEvent:(SentryEvent *)event;
- (void)captureError:(NSError *)error;
- (void)captureException:(NSException *)exception;
- (void)captureMessage:(NSString *)message;

//- `Hub::push_scope()`: Pushes a new scope layer that inherits the previous data. This should return a disposable or stack guard for languages where it makes sense. When the “internally scoped hub” concurrency model is used calls to this are often necessary as otherwise a scope might be accidentally incorrectly shared.

//- `Hub::with_scope(callback)` (optional): In Python this could be a context manager, in Ruby a block function. Pushes and pops a scope for integration work.

//- `Hub::pop_scope()` (optional): Only exists in languages without better resource management. Better to have this function on a return value of `push_scope` or to use `with_scope`. This is also sometimes called `pop_scope_unsafe` to indicate that this method should not be used directly.

//- `Hub::configure_scope(callback)`: Invokes the callback with a mutable reference to the scope for modifications This can also be a `with` statement in languages that have it (Python).

//- `Hub::add_breadcrumb(crumb, hint)`: Adds a breadcrumb to the current scope.
//    - The argument supported should be:
//        - function that creates a breadcrumb
//        - an already created breadcrumb object
//        - a list of breadcrumbs optionally
//    - In languages where we do not have a basic form of overloading only a raw breadcrumb object should be accepted.

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb;

//- `Hub::client()` / `Hub::get_client()` (optional): Accessor or getter that returns the current client or `None`.

//- `Hub::bind_client(new_client)`: Binds a different client to the hub. If the hub is also the owner of the client that was created by `init` it needs to keep a reference to it still if the hub is the object responsible for disposing it.

//- `Hub::unbind_client()` (optional): Optional way to unbind for languages where `bind_client` does not accept nullables.

//- `Hub::last_event_id()`: Should return the last event ID emitted by the current scope. This is for instance used to implement user feedback dialogs.

//- `Hub::run(hub, callback)` `hub.run(callback)`, `run_in_hub(hub, callback)` (optional): Runs a callback with the hub bound as the current hub.

@end

NS_ASSUME_NONNULL_END
