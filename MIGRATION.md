# Upgrading from 5.x to 6.x

In this version there are a few breaking changes. This guide should help you to update your code.

## Configuration Changes

With this version we changed a few things for the configuration:

- [Auto Session Tracking](https://github.com/getsentry/sentry-cocoa/blob/7876949ca78aebfe7883432e35727993c5c30829/Sources/Sentry/include/SentryOptions.h#L101)
is enabled per default.
[This feature](https://docs.sentry.io/product/releases/health/)
is collecting and sending health data about the usage of your
application.

- [Attach stacktraces](https://github.com/getsentry/sentry-cocoa/blob/b5bf9769a158c66a34352556ade243e55f163a27/Sources/Sentry/Public/SentryOptions.h#L109)
 is enabled per default.

- We bumped the minimum iOS version to 9.0.

- Use a BOOL in SentryOptions instead of NSNumber to store booleans.

- We removed [enabled](https://github.com/getsentry/sentry-cocoa/blob/5.2.2/Sources/Sentry/include/SentryOptions.h#L63) on the SentryOptions.

## Breaking Changes

### Store Endpoint

This version uses the [envelope endpoint](https://develop.sentry.dev/sdk/envelopes/).
If you are using an on-premise installation it requires Sentry version
`>= v20.6.0` to work. If you are using sentry.io nothing will change and
no action is needed.

### Sdk Inits

We removed the [deprecated SDK inits](https://github.com/getsentry/sentry-cocoa/blob/5.2.2/Sources/Sentry/include/SentrySDK.h#L35-L47). The recommended way to initialize Sentry is now:

```swift
SentrySDK.start { options in
    options.dsn = "___PUBLIC_DSN___"
    // ...
}
```

```objective-c
[SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
    options.dsn = @"___PUBLIC_DSN___";
    // ...
}];
```

### Cleanup Public Headers

We cleaned up our public headers and made most of our classes private. If you can't access one
of the classes you need please [open an issue](https://github.com/getsentry/sentry-cocoa/issues/new/choose)
and tell us your use case so we either make the class public again or provide another API for you.

### Use new type SentryId for eventId

In 5.x we use a nullable NSString to represent an event ID. The SDK, Hub and Client returned this
nullable NSString for the event ID for capturing messages, events, errors, etc. With 6.x we have a new type SentryId which is not nullable to represent an event ID.
Instead of returning `nil` when an event coulnd't be sent we return `SentryId.empty`.

`5.x`

```swift
let eventId = SentrySDK.capture(message: "A message")
if (nil != eventId) {
    // event was sent
} else {
    // event wasn't sent
}
```

```objective-c
SentryId *eventId = [SentrySDK captureMessage:@"A message"];
if (nil != eventId) {
    // event was sent
} else {
    // event wasn't sent
}
```

`6.x`

```swift
let eventId = SentrySDK.capture(message: "A message")
if (eventId != SentryId.empty) {
    // event was sent
} else {
    // event wasn't sent
}
```

```objective-c
SentryId *eventId = [SentrySDK captureMessage:@"A message"];
if (eventId != SentryId.empty) {
    // event was sent
} else {
    // event wasn't sent
}
```

### Make Scope nonnull for capture methods

In 5.x you could pass a nullable scope to capture methods of the SDK, Hub and Client, such as
`SentrySdk.captureMessage()`. In 6.x we changed the Scope to nonnull and provide overloads
for the Hub and the Client.

Please checkout the [Changelog](CHANGELOG.md) for a complete list of changes.

# Upgrading from 4.x to 5.x

Here are some examples of how the new SDK works.

### Initialization

`4.x.x`

```swift
do {
    Client.shared = try Client(dsn: "___PUBLIC_DSN___")
    try Client.shared?.startCrashHandler()
} catch let error {
    print("\(error)")
}
```

```objective-c
NSError *error = nil;
SentryClient *client = [[SentryClient alloc] initWithDsn:@"___PUBLIC_DSN___" didFailWithError:&error];
SentryClient.sharedClient = client;
[SentryClient.sharedClient startCrashHandlerWithError:&error];
if (nil != error) {
    NSLog(@"%@", error);
}
```

`5.x.x`


```swift
SentrySDK.start(options: [
    "dsn": "___PUBLIC_DSN___",
    "debug": true
])
```

```objective-c
[SentrySDK startWithOptions:@{
    @"dsn": @"___PUBLIC_DSN___",
    @"debug": @(YES)
}];
```

### Add Breadcrumb

`4.x.x`

```swift
Client.shared?.breadcrumbs.add(Breadcrumb(level: .info, category: "test"))
```

```objective-c
[SentryClient.sharedClient.breadcrumbs addBreadcrumb:[[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityInfo category:@"test"]];
```

`5.x.x`

```swift
SentrySDK.addBreadcrumb(Breadcrumb(level: .info, category: "test"))
```

```objective-c
[SentrySDK addBreadcrumb:[[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityInfo category:@"test"]];
```

### CaptureMessage with tags/environment/extra

`4.x.x`

```swift
let event = Event(level: .debug)
event.message = "Test Message"
event.environment = "staging"
event.extra = ["ios": true]
Client.shared?.send(event: event)
```

```objective-c
SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityDebug];
event.message = @"Test Message";
event.environment = @"staging";
event.extra = @{@"ios": @(YES)};
[SentryClient.sharedClient sendEvent:event withCompletionHandler:nil];
```

`5.x.x`

```swift
SentrySDK.capture(message: "Test Message") { (scope) in
    scope.setEnvironment("staging")
    scope.setExtras(["ios": true])
    let u = Sentry.User(userId: "1")
    u.email = "tony@example.com"
    scope.setUser(u)
}
```

```objective-c
[SentrySDK captureMessage:@"Test Message" withScopeBlock:^(SentryScope * _Nonnull scope) {
    [scope setEnvironment:@"staging"];
    [scope setExtras:@{@"ios": @(YES)}];
    SentryUser *user = [[SentryUser alloc] initWithUserId:@"1"];
    user.email = @"tony@example.com";
    [scope setUser:user];
}];
```

### setUser

`4.x.x`

```swift
let u = User(userId: "1")
u.email = "tony@example.com"
Client.shared?.user = user
```

```objective-c
SentryUser *user = [[SentryUser alloc] initWithUserId:@"1"];
user.email = @"tony@example.com";
SentryClient.sharedClient.user = user;
```

`5.x.x`

```swift
let u = Sentry.User(userId: "1")
u.email = "tony@example.com"
SentrySDK.setUser(u)
```

```objective-c
SentryUser *user = [[SentryUser alloc] initWithUserId:@"1"];
user.email = @"tony@example.com";
[SentrySDK setUser:user];
```

For more features, usage examples and configuration options, please visit: https://docs.sentry.io/platforms/cocoa/
