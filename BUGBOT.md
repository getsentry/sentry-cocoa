# BUGBOT.md

Instructions for Cursor Bugbot when reviewing pull requests.

**Read [`REVIEWS.md`](REVIEWS.md) first** — it contains review priorities, SDK-specific concerns, conventions to enforce, and what not to flag.

These rules operationalize the Sentry SDK [philosophy](https://develop.sentry.dev/sdk/getting-started/philosophy/) and [principles](https://develop.sentry.dev/sdk/getting-started/principles/).

## Bugbot-Specific Behavior

- Focus on **bugs and correctness**, not style or nitpicks
- Do not suggest refactors unrelated to the diff
- Keep comments actionable — include a fix or clear explanation
- Limit to high-confidence findings; avoid speculative warnings
- If you flag something from these docs, say so in the review comment
- Respect the project conventions documented in `REVIEWS.md` — do not flag patterns listed under "What NOT to Flag"
