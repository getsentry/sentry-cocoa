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
 _ = SentrySDK(options: [
    "dsn": "___PUBLIC_DSN___",
    "debug": true
])
```

```objective-c
[SentrySDK initWithOptions:@{
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
}
```

```objective-c
[SentrySDK captureMessage:@"Test Message" withScopeBlock:^(SentryScope * _Nonnull scope) {
    [scope setEnvironment:@"staging"];
    [scope setExtras:@{@"ios": @(YES)}];
}];
```

For more features, useage examples and configuration options, please visit: https://docs.sentry.io/platforms/cocoa/