if which sentry-cli >/dev/null; then
export SENTRY_ORG=danielszoketest
export SENTRY_PROJECT=python
ERROR=$(sentry-cli debug-files upload --include-sources "$DWARF_DSYM_FOLDER_PATH" --force-foreground 2>&1 >/dev/null)
if [ ! $? -eq 0 ]; then
echo "error: sentry-cli - $ERROR"
fi
else
echo "error: sentry-cli not installed, download from https://github.com/getsentry/sentry-cli/releases"
fi
