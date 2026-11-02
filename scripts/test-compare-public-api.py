import copy
import json
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest

SCRIPT = runpy.run_path(str(Path(__file__).with_name("compare-public-api.py")))
normalize = SCRIPT["normalize"]
compare = SCRIPT["compare_declarations"]


def function(types):
    return {"kind": "Function", "printedName": "example(_:_:)",
            "declKind": "Func", "moduleName": "Sentry",
            "children": [{"kind": "TypeNominal", "printedName": name} for name in types]}


class ComparisonTests(unittest.TestCase):
    def test_module_names_and_symbol_identity_are_normalized(self):
        old = {"moduleName": "Sentry", "printedName": "Sentry.Options", "usr": "old"}
        new = {"moduleName": "SentrySwift", "printedName": "SentrySwift.Options", "usr": "new"}
        self.assertEqual(normalize(old), normalize(new))
        self.assertEqual(normalize("SentryHeaders.Event"), "Sentry.Event")
        self.assertEqual(normalize("OtherSentrySwift"), "OtherSentrySwift")

    def test_parameter_order_is_not_sorted_away(self):
        old = normalize(function(["()", "Swift.Int", "Swift.String"]))
        new = normalize(function(["()", "Swift.String", "Swift.Int"]))
        self.assertEqual(compare([old], [new])[0]["change"], "changed")

    def test_overloads_are_not_overwritten(self):
        first = function(["()", "Swift.Int", "Swift.String"])
        second = function(["()", "Swift.Int", "Swift.Int"])
        self.assertEqual(compare([first, second], [second])[0]["change"], "changed")
        self.assertEqual(compare([first, second], [second, first]), [])

    def test_member_order_is_not_a_difference(self):
        first = function(["()", "Swift.Int", "Swift.String"])
        second = {"kind": "Var", "printedName": "value", "declKind": "Var"}
        old = {"kind": "TypeDecl", "printedName": "Options", "children": [first, second]}
        new = {**old, "children": [second, first]}
        self.assertEqual(normalize(old), normalize(new))

    def test_missing_members_are_reported_by_path(self):
        old = {"kind": "TypeDecl", "printedName": "TransactionContext", "children": [
            {"kind": "Var", "printedName": "nameSource", "declKind": "Var"}]}
        new = {**old, "children": []}
        self.assertEqual(compare([old], [new]), [{
            "change": "removed", "path": "TransactionContext.nameSource", "kind": "Var"}])

    def test_availability_and_type_attributes_are_preserved(self):
        old = function(["()", "Swift.Int"])
        new = {**old, "intro_iOS": "17.0"}
        self.assertEqual(compare([normalize(old)], [normalize(new)])[0]["change"], "changed")
        left = {"kind": "TypeDecl", "printedName": "Options", "children": []}
        right = {**left, "declAttributes": ["Final"]}
        self.assertEqual(compare([normalize(left)], [normalize(right)])[0]["change"], "changed")

    def test_mutability_changes_are_preserved(self):
        old = {"kind": "Var", "printedName": "value", "isLet": True}
        new = {**old, "isLet": False}
        self.assertEqual(compare([normalize(old)], [normalize(new)])[0]["change"], "changed")

    def test_cli_writes_non_blocking_report_with_missing_members(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old = {"kind": "TypeDecl", "printedName": "TransactionContext", "children": [
                {"kind": "Var", "printedName": "nameSource", "declKind": "Var"}]}
            self.write_dump(root / "old.json", [old])
            self.write_dump(root / "new.json", [{**old, "children": []}])
            result = self.run_cli(root)
            self.assertEqual(result.returncode, 1, result.stderr)
            report = (root / "report" / "summary.md").read_text()
            self.assertIn("TransactionContext.nameSource", report)
            self.assertIn("informational", report)
            self.assertIn("Missing from SwiftPM", report)

    def test_cli_rejects_empty_or_malformed_dumps(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_dump(root / "old.json", [function(["()", "Swift.Int"])])
            for data in ("{", "{}", '{"ABIRoot": null}', json.dumps({
                    "ABIRoot": {"kind": "Root", "children": [], "json_format_version": 8}})):
                with self.subTest(data=data):
                    (root / "new.json").write_text(data)
                    result = self.run_cli(root)
                    self.assertEqual(result.returncode, 2)
                    self.assertFalse((root / "report" / "summary.md").exists())

    def test_cli_rejects_different_format_versions(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            node = function(["()", "Swift.Int"])
            self.write_dump(root / "old.json", [node], version=7)
            self.write_dump(root / "new.json", [node], version=8)
            self.assertEqual(self.run_cli(root).returncode, 2)

    def test_cli_equal_inputs_return_success_and_preserve_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("old.json", "new.json"):
                self.write_dump(root / name, [function(["()", "Swift.Int"])])
            original = (root / "old.json").read_bytes()
            result = self.run_cli(root)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((root / "old.json").read_bytes(), original)
            self.assertEqual((root / "new.json").read_bytes(), original)
            self.assertEqual((root / "report" / "api.diff").read_text(), "")
            self.assertIn("No source API differences", (root / "report" / "summary.md").read_text())

    def test_report_escapes_declaration_markup(self):
        report = SCRIPT["markdown_report"]([{
            "change": "removed", "path": "Example.<T|U>`\\nname", "kind": "TypeDecl"}])
        self.assertNotIn("<T|U>", report)
        self.assertIn("&lt;T&#124;U&gt;", report)
        self.assertNotIn("`\\nname", report)

    @staticmethod
    def write_dump(path, children, version=8):
        path.write_text(json.dumps({"ABIRoot": {
            "kind": "Root", "json_format_version": version, "children": children}}))

    @staticmethod
    def run_cli(root):
        return subprocess.run([
            sys.executable, str(Path(__file__).with_name("compare-public-api.py")),
            "--baseline", str(root / "old.json"), "--candidate", str(root / "new.json"),
            "--output-dir", str(root / "report")], capture_output=True, text=True)

    def test_normalization_does_not_mutate_inputs(self):
        old = function(["()", "Swift.Int", "Swift.String"])
        saved = copy.deepcopy(old)
        normalize(old)
        self.assertEqual(old, saved)


if __name__ == "__main__":
    unittest.main()
