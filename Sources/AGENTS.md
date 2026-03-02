# Sources — Agent Instructions

## Objective-C Conventions

### Avoid `+new`, Use `[[Class alloc] init]`

Never use `[NSObject new]` or `[ClassName new]` in Objective-C code. Always use `[[ClassName alloc] init]` instead.

```objc
// Prefer
NSMutableArray *items = [[NSMutableArray alloc] init];
NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] init];

// Avoid
NSMutableArray *items = [NSMutableArray new];
NSMutableDictionary *data = [NSMutableDictionary new];
SentryBreadcrumb *crumb = [SentryBreadcrumb new];
```

**Rationale:** While `+new` is effectively equivalent to `[[self alloc] init]`, it hides the two-phase creation and the choice of designated initializer behind a single opaque call. Using `[[Class alloc] init…]` is the idiomatic Objective-C pattern that makes allocation and initialization clear to readers and consistent with designated initializer usage.
