# 3rd Party Library Integrations in Other Repositories

This document outlines our approach to managing integrations with **3rd party libraries** (such as CocoaLumberjack, SwiftLog, etc.).

We have identified that **SPM** downloads _all_ declared dependencies in a package, even if none the added actually added modules use them.

This means that if `sentry-cocoa` declares dependencies like **CocoaLumberjack** or **SwiftLog**, _all_ downstream consumers download these libraries, even if they don't use the corresponding integrations.

To avoid forcing unnecessary 3rd party dependencies on users, we already agreed to **remove the integrations from the main Package.swift on on this repository**.

However, maintaining multiple repositories introduces overhead for the team.

### Goals

- Avoid forcing users to download unused third-party dependencies.
- Keep integration code discoverable, maintainable, and testable.
- Minimize additional team workload.

**Extras:**

- Maintain flexibility in release schedules.

### Agreed solution

- **3: Keep all code in `sentry-cocoa`, but mirror releases into individual repositories**

  SPM users import the integration repos, but implementation lives in `sentry-cocoa`.

  Automated workflows push integration-specific code into dedicated repos during release.

  The idea comes from this repo:

  https://github.com/marvinpinto/action-automatic-releases

> [!NOTE]
> For other options that were considered, see the [3rd Party Library Integrations decision in DECISIONS.md](DECISIONS.md#3rd-party-library-integrations).

### Contributing moving forward

All integration development will continue in the main `sentry-cocoa` repository, organized in dedicated subdirectories for clean CI isolation.

#### Directory Structure

Each integration will be self-contained in `3rd-party-integration/INTEGRATION-NAME/` with:

- `Sources/` - Integration source code
- `Tests/` - Test for the integration
- `README.md` - Integration-specific documentation
- `Package.swift` - SPM package definition
- `*.podspec` - CocoaPods specification

**Example:**

```
3rd-party-integration/
  ├── SentryCocoaLumberjack/
  │   ├── Sources/
  │   ├── README.md
  │   ├── Package.swift
  │   └── SentryCocoaLumberjack.podspec
  └── SentrySwiftLog/
      ├── Sources/
      ├── README.md
      ├── Package.swift
      └── SentrySwiftLog.podspec
```

Since SPM fails to resolve dependencies if the folder has the same name as one of the dependencies, we cannot use the library name as the folder name.
We will use the name of our dependency, for example:

- `SentryCocoaLumberjack` for `CocoaLumberjack`
- `SentrySwiftLog` for `SwiftLog`

#### Release Process

During each release, automated workflows will:

1. Extract the integration directory contents
2. Push to the dedicated integration repository (e.g., `sentry-cocoa-swift-log`)
3. Create a tagged release matching the main SDK version

> [!NOTE]
> This process will be automated via GitHub Actions. Initial releases may be handled manually while tooling is being developed.
