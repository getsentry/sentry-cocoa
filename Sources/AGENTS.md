# Sources

## Objective-C

### No `+new`

Use `[[Class alloc] init]`, not `[Class new]`:

```objc
// Correct
NSMutableArray *items = [[NSMutableArray alloc] init];
SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] init];

// Wrong
NSMutableArray *items = [NSMutableArray new];
SentryBreadcrumb *crumb = [SentryBreadcrumb new];
```
