# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Guidelines

**ALWAYS adhere to AGENTS.md at all times.** This file contains comprehensive development patterns, conventions, and best practices for the Sentry Cocoa SDK project.

## Critical Rules

1. **Read AGENTS.md**: Familiarize yourself with all guidelines before making changes
2. **No AI References**: NEVER mention AI assistant names (Claude, ChatGPT, Cursor, etc.) in:
   - Git commit messages
   - Pull request titles or descriptions
   - Code comments (unless technically relevant)
   - Co-authored-by tags
   - Generated-with footers

3. **Follow Conventions**: All code, commits, and PRs must follow the patterns documented in AGENTS.md:
   - Compilation requirements for all platforms (iOS, macOS, tvOS, watchOS, visionOS)
   - Testing requirements before commits and PRs
   - Documentation standards
   - GitHub workflow naming conventions
   - File filter configuration patterns
   - Concurrency strategies for CI workflows

## Quick Reference

- Use `make help` to discover available commands
- Format code: `make format`
- Run static analysis: `make analyze`
- Run unit tests: `make run-test-server && make test`
- Run important UI tests: `make test-ui-critical`
- Build XCFramework deliverables: `make build-xcframework`
- Lint pod deliverable: `make pod-lint`
- Follow file structure and naming conventions in AGENTS.md
- Create focused, atomic commits with clear messages
