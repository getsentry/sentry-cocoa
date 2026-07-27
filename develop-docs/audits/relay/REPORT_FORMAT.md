# Report format & Slack posting — Cocoa ↔ Relay

Three outputs per run, posted as one Slack message plus threaded replies. Slack uses _mrkdwn_, not full Markdown — no tables, `*bold*` (single asterisks), `` `code` ``, `<url|label>` links, `•` bullets. Keep the delta short; put detail in the thread.

## 1. Main message — delta

Header + one count line + NEW/RESOLVED bullets. Quiet week = a single ✅ line. Skimmable in 5 seconds.

```
:shield: *Cocoa ↔ Relay conformance* — <DATE> · sentry-cocoa@<SHA>
NEW <n>  ·  RESOLVED <n>  ·  known <n>  ·  conformant <OK|:rotating_light: BROKEN>

:warning: *NEW*
• [NEW-1 | <SEVERITY>] <area> — <file (symbol)> — <one-line summary>
• …

:white_check_mark: *RESOLVED* (suggest flipping to `fixed` in FINDINGS.md)
• <RELAY-###> <area> — <summary>

:thread: TLDR + full report in thread.
```

Quiet week:

```
:shield: *Cocoa ↔ Relay conformance* — <DATE> · sentry-cocoa@<SHA>
:white_check_mark: No new conformance drift. (known <n> · conformant OK)
```

- A regression (matched `fixed` tombstone or broken conformant-checklist item) is a NEW bullet prefixed `:rotating_light: REGRESSION`, always HIGH.
- Validation runs (see `VALIDATION.md`) prefix the header with `:test_tube: VALIDATION RUN —` and end with `VALIDATION PASSED` / `VALIDATION FAILED`.
- NEW findings use provisional labels `NEW-1`, `NEW-2`, … — permanent `RELAY-###` IDs are assigned by the human who triages them into `FINDINGS.md`.

## 2. Thread reply 1 — TLDR (management summary)

For humans deciding whether to care. Per NEW finding, 2–4 plain sentences: what is broken, what the user-visible impact is, how big the blast radius is. No file paths, no jargon.

```
:memo: *TLDR*

*NEW-1 — <plain-English title>*
<What's wrong, in one sentence.> <What data is lost/mis-routed and for whom.> <Why it fails silently / how it would be noticed.>
```

## 3. Thread reply 2 — full report (agent-pickup context)

The standalone snapshot: everything an agent (or human) needs to pick a finding up cold. Grouped NEW → RESOLVED → KNOWN (counts only for KNOWN unless something changed), ending with the conformant-checklist result. Per NEW finding:

```
*NEW-1 · <SEVERITY> · <area>*
Location: <file> (<symbol/method>)
Wire strings: <the exact literal(s) involved>
Spec: <develop-docs URL and/or Relay source file + symbol>
Failure mode: <what silently goes wrong, end to end>
Verify: <1–3 concrete steps to confirm (e.g. which test to write, which header to send)>
Create issue: <pre-filled link, see below>
```

If the thread reply exceeds Slack's ~3000-char practical limit, split into multiple replies or upload `report.md` as a file in the thread.

## One-click GitHub issue links

Each NEW finding gets a pre-filled issue URL so triage is a single click:

```
https://github.com/getsentry/sentry-cocoa/issues/new?title=<urlencoded title>&body=<urlencoded body>&labels=Relay-Conformance
```

- **Title:** `<area>: <one-line summary>`
- **Body:** the finding's full-report block (location, wire strings, spec citation, failure mode, verify steps) plus a line `Found by the weekly Relay conformance audit (<DATE>, sentry-cocoa@<SHA>). Triage: assign the next RELAY-### ID in develop-docs/audits/relay/FINDINGS.md.`
- Keep the URL under ~8000 chars; if the body is too long, trim to location + failure mode + a pointer to the Slack thread.

## Posting recipes

### Via claude.ai Slack connector (current setup)

Post the delta as the main message, capture its `message_ts`, then post replies 1 and 2 with `thread_ts` set to it. Verify each response is ok; if the connector is unavailable or a post fails, print the full delta + TLDR + report to the run output and state clearly that the Slack post FAILED — do not report success.

### Via bot token (future GitHub Actions migration)

Requires `SLACK_BOT_TOKEN` (scope `chat:write`) and `SLACK_CHANNEL_ID`. Threading needs the Web API — an incoming webhook cannot reply in-thread.

````bash
TS=$(curl -sS -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  -H 'Content-type: application/json; charset=utf-8' \
  --data "$(jq -n --arg c "$SLACK_CHANNEL_ID" --arg t "$DELTA_TEXT" '{channel:$c, text:$t}')" \
  | jq -r 'if .ok then .ts else ("ERR:"+.error) end')
[ "${TS#ERR:}" = "$TS" ] || { echo "Slack post failed: $TS"; exit 1; }

curl -sS -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  -H 'Content-type: application/json; charset=utf-8' \
  --data "$(jq -n --arg c "$SLACK_CHANNEL_ID" --arg ts "$TS" \
            --rawfile body full-report.md '{channel:$c, thread_ts:$ts, text:("```\n"+$body+"\n```")}')"
````

For a long report, upload it as a file in the thread instead: `files.getUploadURLExternal` → PUT the bytes → `files.completeUploadExternal` with `channel_id` + `thread_ts` (the old `files.upload` is deprecated). Always check `.ok` and log `.error` — a silent Slack outage must not look like "no drift."
