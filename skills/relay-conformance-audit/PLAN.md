# Rollout plan

Status: prepared for draft PR — nothing committed yet.

Done:

- ✅ Skill authored at `skills/relay-conformance-audit/` (tracked path), wired via `agents.toml` `path:` source; dotagents mirrors it into `.agents/skills/` for all agents (`npx @sentry/dotagents install` after edits).
- ✅ First real run on `main@50fe369eb` (2026-07-27): 10 needs-action mismatches (2 HIGH, 3 MEDIUM, 5 LOW), 9 ignored.
- ✅ Blind validation PASSED (2026-07-27): audit of the pinned pre-fix commit surfaced #8322 at HIGH with exact location/failure mode; the `main` run did not report it. Procedure documented in SKILL.md "Validation".

Next:

1. **Draft PR** — commit `skills/relay-conformance-audit/` + the `agents.toml` entry (docs-only, `#skip-changelog`). Open as draft.
2. **Triage the first run's mismatches** — for each: file a GitHub issue (→ Tracked in `references/findings.md`) or add to Ignored with a scenario. Includes verifying the tracesSampler `sample_rand` re-roll candidate on `main`. Goal: next run says "nothing needs action".
3. **claude.ai routine** — weekly routine (personal account, Slack connector → `#team-sdk-apple`) with the one-line prompt from SKILL.md "Running it". Iterate on noise. Disable the old personal routine (`trig_01TgfZKrPC6oLU3osDrF5uKu`).
4. **CI (later)** — scheduled GitHub Actions workflow invoking Claude Code headlessly with the same prompt; secrets `ANTHROPIC_API_KEY`, `SLACK_BOT_TOKEN`, `SLACK_CHANNEL_ID`; `workflow_dispatch` validation mode failing on `VALIDATION FAILED`. Retire the routine.

Maintenance in every phase: humans edit `references/findings.md` via reviewed PRs (issue filed → Tracked; won't-fix → Ignored + scenario; fixed → remove); the audit never writes it.
