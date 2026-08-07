# Changelog

## Unreleased

### Features

- Process pending KSCrash reports into fatal Sentry events in `Sentry+KSCrash` (#8515)
- Install KSCrash crash handler in `Sentry+KSCrash` with production-safe monitors matching SentryCrash's existing monitor set (#8469)
  - Respect `options.enableMemoryIntrospection` when configuring KSCrash
- Add `options.dataCollection` to configure data collection behaviour (#8448)
  - Allows dictionary initialization for `options.dataCollection` (#8371)
  - Renamed `options.dataCollection.queryParams` to `options.dataCollection.urlQueryParams` (#8414)
  - Add query parameter filtering for network spans, breadcrumbs, and failed requests using `options.dataCollection.urlQueryParams` (#8414)
  - Enable automatic user information for logs, metrics, and IP inference by default; configure it with `options.dataCollection.userInfo` (#8254)
  - Add HTTP header and cookie filtering for failed requests using `options.dataCollection` (#8460)
  - Scrub sensitive Session Replay request and response body values, replacing unparseable bodies with `[Filtered]` (#8547)

### Breaking Changes

- Enable logging by default (#8717)
- Remove `sendDefaultPii`; use `dataCollection` to configure automatic data collection (#8253)
- Remove Objective-C `@objc` attributes from SentrySDK (#8308)
- Remove deprecated `locale` from device context; use `locale` in culture context instead (#8325)
- Change `SentryRequest.cookies` from a string to a dictionary of cookie names and values (#8460)
- Remove data collection options without applicable Cocoa collectors (#8563)

### Fixes

- Filter sensitive values from selected Session Replay network headers and cookies (#8566)
- Omit failed-request headers when `options.dataCollection.httpHeaders` is disabled (#8562)
- Normalize profiling CPU usage to 0–100 percent (#8323)
- Bump KSCrash to `2.6.0-beta.5`
