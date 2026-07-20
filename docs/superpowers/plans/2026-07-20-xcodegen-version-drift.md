# XcodeGen Version Drift Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add XcodeGen to the existing SwiftLint and clang-format version drift checks and automated version-update workflow.

**Architecture:** Store XcodeGen's normalized numeric version in `scripts/.xcodegen-version`. The existing update and check scripts will write and compare that value, while CI cache invalidation, file filters, and the updater workflow will treat it like the other tooling version files.

**Tech Stack:** Bash, XcodeGen, Homebrew, Make, GitHub Actions YAML

## Global Constraints

- Record XcodeGen version `2.46.0` as a normalized numeric string.
- Keep one version file per tool.
- Preserve the existing combined drift-check failure behavior and resolution message.
- Do not change XcodeGen installation behavior.
- Create a dedicated automated XcodeGen update PR.
- Do not commit changes unless the user explicitly requests a commit.

---

## File Structure

- Create `scripts/.xcodegen-version`: authoritative expected XcodeGen version.
- Modify `scripts/update-tooling-versions.sh`: normalize and record the installed XcodeGen version.
- Modify `scripts/check-tooling-versions.sh`: compare installed and expected XcodeGen versions.
- Modify `.github/actions/cache-homebrew/action.yml`: invalidate the Homebrew cache when the XcodeGen version record changes.
- Modify `.github/file-filters.yml`: run tooling-update and build validation when the XcodeGen version record changes.
- Modify `.github/workflows/auto-update-tools.yml`: open a separate XcodeGen update PR.

### Task 1: Add XcodeGen to the local drift-check contract

**Files:**

- Create: `scripts/.xcodegen-version`
- Modify: `scripts/update-tooling-versions.sh:20`
- Modify: `scripts/check-tooling-versions.sh:22-37`

**Interfaces:**

- Consumes: `xcodegen --version`, whose output is `Version: <numeric-version>`.
- Produces: `scripts/.xcodegen-version` containing only `<numeric-version>` followed by a newline.
- Produces: `make check-versions` failure output containing `xcodegen version mismatch` when installed and recorded versions differ.

- [ ] **Step 1: Establish the failing drift-check expectation**

Create `scripts/.xcodegen-version` with an intentionally incorrect value:

```text
0.0.0
```

Run:

```bash
make check-versions
```

Expected: the command still exits successfully because `scripts/check-tooling-versions.sh` does not yet read `.xcodegen-version`. This demonstrates the missing behavior.

- [ ] **Step 2: Add XcodeGen to the update script**

Append this command after the SwiftLint version write in `scripts/update-tooling-versions.sh`:

```bash
xcodegen --version | awk -F ': ' '{print $2}' > .xcodegen-version
```

- [ ] **Step 3: Add XcodeGen to the check script**

After the SwiftLint local-version variables in `scripts/check-tooling-versions.sh`, add:

```bash
REMOTE_XCODEGEN_VERSION=$(cat .xcodegen-version)
LOCAL_XCODEGEN_VERSION=$(xcodegen --version | awk -F ': ' '{print $2}')
```

After the SwiftLint mismatch block, add:

```bash
if [ "${LOCAL_XCODEGEN_VERSION}" != "${REMOTE_XCODEGEN_VERSION}" ]; then
    echo "xcodegen version mismatch, expected: ${REMOTE_XCODEGEN_VERSION}, but found: ${LOCAL_XCODEGEN_VERSION}"
    SENTRY_TOOLING_UP_TO_DATE=false
fi
```

- [ ] **Step 4: Verify mismatch detection now fails**

Run:

```bash
make check-versions
```

Expected: exit code `1` and output containing:

```text
xcodegen version mismatch, expected: 0.0.0, but found: 2.46.0
```

- [ ] **Step 5: Record the installed version through the supported update path**

Run:

```bash
make update-versions
```

Expected: `scripts/.xcodegen-version` contains exactly:

```text
2.46.0
```

- [ ] **Step 6: Verify the matching version succeeds**

Run:

```bash
make check-versions
```

Expected: exit code `0`, with the existing `rbenv version` output and no mismatch messages.

- [ ] **Step 7: Run focused shell validation**

Run:

```bash
shellcheck scripts/check-tooling-versions.sh scripts/update-tooling-versions.sh
```

Expected: exit code `0` with no diagnostics.

### Task 2: Integrate the XcodeGen version record into CI selection and caching

**Files:**

- Modify: `.github/actions/cache-homebrew/action.yml:21`
- Modify: `.github/file-filters.yml:177-197`
- Modify: `.github/file-filters.yml:364-390`

**Interfaces:**

- Consumes: `scripts/.xcodegen-version` from Task 1.
- Produces: a Homebrew cache key that changes with the XcodeGen version record.
- Produces: `run_auto_update_tools_for_prs` and `run_build_for_prs` matches for XcodeGen version changes.

- [ ] **Step 1: Add XcodeGen to the Homebrew cache key**

Change the `hashFiles` argument in `.github/actions/cache-homebrew/action.yml` to:

```yaml
key: homebrew-${{ runner.os }}-${{ runner.arch }}-${{ steps.week.outputs.week }}-${{ hashFiles('scripts/.clang-format-version', 'scripts/.swiftlint-version', 'scripts/.xcodegen-version', '.ruby-version', 'Brewfile*') }}
```

- [ ] **Step 2: Trigger tooling-update validation**

Add this entry beside the other tooling version records under `run_auto_update_tools_for_prs`:

```yaml
- "scripts/.xcodegen-version"
```

The resulting tool configuration list must contain all three records:

```yaml
- "scripts/.clang-format-version"
- "scripts/.swiftlint-version"
- "scripts/.xcodegen-version"
```

- [ ] **Step 3: Trigger build validation**

Add a tool configuration section to `run_build_for_prs` before its build configuration section:

```yaml
# Tool configuration
- "scripts/.xcodegen-version"
```

This ensures an XcodeGen drift-record change exercises the workflows that regenerate sample projects.

- [ ] **Step 4: Validate the YAML files**

Run:

```bash
pre-commit run check-yaml --files .github/actions/cache-homebrew/action.yml .github/file-filters.yml
```

Expected: `Passed`.

### Task 3: Add the automated XcodeGen updater PR

**Files:**

- Modify: `.github/workflows/auto-update-tools.yml:104-116`

**Interfaces:**

- Consumes: `scripts/.xcodegen-version` updated by `make update-versions`.
- Produces: branch `github-actions/auto-update-tools-xcodegen` and PR title `chore(deps): Update xcodegen version` on scheduled or manually dispatched runs.

- [ ] **Step 1: Add the XcodeGen PR step**

Insert this step after the SwiftLint PR step:

```yaml
- name: Create pull request for xcodegen version
  uses: peter-evans/create-pull-request@5f6978faf089d4d20b00c7766989d076bb2fc7f1 # v8.1.1
  if: ${{ github.event_name == 'schedule' || github.event_name == 'workflow_dispatch' }}
  with:
    token: ${{ steps.app_token.outputs.token }}
    add-paths: scripts/.xcodegen-version
    branch: github-actions/auto-update-tools-xcodegen
    commit-message: "chore(deps): Update xcodegen version"
    delete-branch: true
    title: "chore(deps): Update xcodegen version"
    sign-commits: true
    base: main
```

- [ ] **Step 2: Validate the workflow schema**

Run:

```bash
pre-commit run check-github-workflows --files .github/workflows/auto-update-tools.yml
```

Expected: `Passed`.

- [ ] **Step 3: Validate workflow and filter formatting**

Run:

```bash
dprint check .github/workflows/auto-update-tools.yml .github/file-filters.yml .github/actions/cache-homebrew/action.yml
```

Expected: exit code `0` with no formatting differences.

### Task 4: Run repository verification and inspect the final change

**Files:**

- Verify all files changed in Tasks 1 through 3.

**Interfaces:**

- Consumes: the completed drift check and CI integration.
- Produces: evidence that formatting, static analysis, and focused behavior checks pass.

- [ ] **Step 1: Run repository formatting**

Run:

```bash
make format
```

Expected: exit code `0`.

- [ ] **Step 2: Re-run the focused version check after formatting**

Run:

```bash
make check-versions
```

Expected: exit code `0` and no mismatch messages.

- [ ] **Step 3: Run static analysis**

Run:

```bash
make analyze
```

Expected: exit code `0`. If reduced output does not explain a failure, inspect the relevant `raw-*-output.log` file before changing code.

- [ ] **Step 4: Inspect tracked and untracked changes**

Run:

```bash
git status --short
```

Expected changed implementation files:

```text
.github/actions/cache-homebrew/action.yml
.github/file-filters.yml
.github/workflows/auto-update-tools.yml
scripts/.xcodegen-version
scripts/check-tooling-versions.sh
scripts/update-tooling-versions.sh
```

The approved design and implementation plan under `docs/superpowers/` will also remain untracked or modified unless the user asks to include or remove them.

- [ ] **Step 5: Review the implementation diff**

Run:

```bash
git diff -- .github/actions/cache-homebrew/action.yml .github/file-filters.yml .github/workflows/auto-update-tools.yml scripts/.xcodegen-version scripts/check-tooling-versions.sh scripts/update-tooling-versions.sh
```

Expected: only the approved XcodeGen drift-check, cache, filter, and updater integration changes.

- [ ] **Step 6: Report verification without committing**

Summarize the changed files and exact commands run. Do not run `git add`, `git commit`, or create a pull request unless the user explicitly requests it.
