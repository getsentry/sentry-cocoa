# Integrations in other repositories

We have identified that **SPM** downloads _all_ declared dependencies in a package, even if none the added actually added modules use them.

This means that if `sentry-cocoa` declares dependencies like **CocoaLumberjack** or **SwiftLog**, _all_ downstream consumers download these libraries, even if they don’t use the corresponding integrations.

To avoid forcing unnecessary dependencies on users, we already agreed to **remove integrations from the main repository**.

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

  Pros:

  - Source of truth stays in **one repository**.
  - Development flow simpler (single CI, single contribution workflow).
  - Users still get the benefit of **modular SPM dependencies**, without downloading everything.
  - Mirrors how some SDKs manage platform-specific or optional components

  Cons:

  - Requires building a **custom mirroring release workflow**.
  - Potential risk of divergence if mirror fails or is misconfigured.
  - Release cadence may still be tied to `sentry-cocoa` unless new workflows are built.
  - Requires tooling to ensure code in the main repo remains cleanly partitioned.

### Discarded options:

<details>
  <summary>See options</summary>
- **1: Move all integrations into new repository/ies**

    Two possible sub-variants:

    - Option A — One repository containing *all* integrations
    - Option B — Group integrations by theme (e.g., logging integrations, feature-flag integrations)

    Pros:

    - Integrations _can_ (doesn't mind they should) have **independent release schedules** from `sentry-cocoa`.
    - The main `sentry-cocoa` package remains **lean** and dependency-free.
    - Users only download dependencies for the specific integrations they choose.
    - The code remains centralized enough that cross-integration changes are simpler

    Cons:

    - Increases team workload due to more repositories to monitor.
    - Requires many new repository setup.
    - Cross-repo changes become harder.
    - Risk of fragmentation: documentation, ownership, issue tracking become more distributed.
    - Changes may require PRs across multiple repos.

- **2: One integration per repository**

  Pros:

  - Users import only the exact integration they need.
  - Extremely granular release management.
  - Clean separation of concerns and dependency trees.

  Cons:

  - This is the **maximum possible repo overhead**.
  - Cross-integration changes require coordinating multiple PRs.
  - Significant overhead in monitoring issues and security alerts.
  - Harder to keep documentation centralized or coherent.
- **4: Make Package.swift dynamic**

  This is a wild idea, but we have to double check if using `canImport(SwiftLog)` works for enabling the SwiftLog dependency.

  Needs a POC to confirm this is possible

</details>
