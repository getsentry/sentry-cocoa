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

> [!NOTE]
> For other options that were considered, see the [3rd Party Library Integrations decision in DECISIONS.md](DECISIONS.md#3rd-party-library-integrations).
