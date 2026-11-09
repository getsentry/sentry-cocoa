"""Check build/test destinations without invoking Xcode or a simulator."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parent / "sentry-xcodebuild.sh"


class XcodebuildDestinationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="sentry xcodebuild ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.calls = self.root / "calls.jsonl"
        self.tools = self.root / "tools"
        self.tools.mkdir()
        self.env = {**os.environ, "PATH": f"{self.tools}:{os.environ['PATH']}",
                    "GITHUB_ACTIONS": "false", "FOR_AGENTS": "true",
                    "XCODEBUILD_CALLS": str(self.calls), "HOST_ARCH": "arm64"}
        self.tool("uname", '''#!/bin/bash
set -euo pipefail
[[ "$*" == -m ]]
printf '%s\\n' "$HOST_ARCH"
''')
        self.tool("xcodebuild", '''#!/usr/bin/env python3
import json, os, sys
with open(os.environ["XCODEBUILD_CALLS"], "a") as output:
    output.write(json.dumps(sys.argv[1:]) + "\\n")
''')
        self.tool("xcbeautify", '''#!/usr/bin/env python3
import sys
sys.stdout.write(sys.stdin.read())
''')
        self.tool("xcrun", '''#!/bin/bash
set -euo pipefail
[[ "$*" == 'simctl list runtimes -v' ]]
printf '%s\\n' 'iOS 18.5 (18.5 - fixture)'
''')

    def tool(self, name, contents):
        path = self.tools / name
        path.write_text(contents)
        path.chmod(0o755)

    def run_script(self, *args):
        self.calls.unlink(missing_ok=True)
        result = subprocess.run([str(SCRIPT), *args], cwd=self.root, env=self.env,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout)
        return [json.loads(line) for line in self.calls.read_text().splitlines()]

    def assert_destination(self, calls, destination, actions):
        self.assertEqual([call[-1] for call in calls], actions)
        for call in calls:
            self.assertEqual(call[call.index("-destination") + 1], destination)

    def test_macos_uses_host_architecture_for_each_action(self):
        for arch in ("arm64", "x86_64"):
            self.env["HOST_ARCH"] = arch
            for command in ("build", "build-for-testing", "test-without-building", "test"):
                with self.subTest(arch=arch, command=command):
                    calls = self.run_script("--platform", "macOS", "--command", command)
                    actions = (["build-for-testing", "test-without-building"]
                               if command == "test" else [command])
                    self.assert_destination(calls, f"platform=macOS,arch={arch}", actions)

    def test_explicit_destination_is_preserved(self):
        for destination in ("platform=macOS,arch=x86_64", "generic/platform=macOS"):
            with self.subTest(destination=destination):
                calls = self.run_script("--platform", "macOS", "--command", "test",
                                        "--destination", destination)
                self.assert_destination(calls, destination,
                                        ["build-for-testing", "test-without-building"])

    def test_other_platform_destinations_are_preserved(self):
        for platform, options, destination in (
            ("Catalyst", [], "platform=macOS,variant=Mac Catalyst"),
            ("iOS", ["--os", "18.5", "--device", "iPhone 16e"],
             "platform=iOS Simulator,OS=18.5,name=iPhone 16e"),
        ):
            with self.subTest(platform=platform):
                calls = self.run_script("--platform", platform, "--command", "test", *options)
                self.assert_destination(calls, destination,
                                        ["build-for-testing", "test-without-building"])


if __name__ == "__main__":
    unittest.main()
