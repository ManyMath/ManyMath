"""Exercise Git and hosted dependency contracts and fixture drift rejection."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import integration


class IntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "application"
        self.source = Path(self.temp.name) / "source with spaces"
        (self.root / "tool").mkdir(parents=True)
        (self.root / ".dart_tool").mkdir()
        (self.source / "package").mkdir(parents=True)
        (self.source / "package/pubspec.yaml").write_text("name: fixture_package\n")
        (self.source / "example.json").write_bytes(b'{"fixture":true}\n')
        self.git("init", "-q")
        self.git("add", ".")
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                 "-c", "core.hooksPath=/dev/null", "commit", "-qm", "fixture")
        self.pin = self.git("rev-parse", "HEAD").strip()
        data = (self.source / "example.json").read_bytes()
        (self.root / "fixture.json").write_bytes(data)
        self.lock = {
            "schema": 1,
            "dependencies": {"fixture_package": {
                "revision": self.pin, "path": "package"}},
            "fixtures": [{"dependency": "fixture_package", "source_path": "example.json",
                          "local_path": "fixture.json", "sha256": hashlib.sha256(data).hexdigest()}],
        }
        self.write_lock()
        (self.root / ".dart_tool/package_config.json").write_text(json.dumps({
            "packages": [{"name": "fixture_package", "rootUri": (self.source / "package").as_uri()}]
        }))
        self.patch = patch.object(integration, "ROOT", self.root)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.source), *args], text=True)

    def write_lock(self):
        (self.root / "tool/integration-lock.json").write_text(json.dumps(self.lock))

    def test_exact_contract_with_encoded_space_uri(self):
        integration.verify()
        self.assertEqual(integration.package_root("fixture_package"), self.source / "package")

    def test_wrong_revision_is_rejected(self):
        self.lock["dependencies"]["fixture_package"]["revision"] = "0" * 40
        self.write_lock()
        with self.assertRaisesRegex(ValueError, "immutable integration pin"):
            integration.verify()

    def test_modified_resolved_source_is_rejected(self):
        (self.source / "package/pubspec.yaml").write_text("name: other\n")
        with self.assertRaisesRegex(ValueError, "local modifications"):
            integration.verify()

    def test_injected_package_source_is_rejected(self):
        (self.source / "package/injected.dart").write_text("void main() {}\n")
        with self.assertRaisesRegex(ValueError, "local modifications"):
            integration.verify()

    def test_wrong_package_directory_is_rejected(self):
        self.lock["dependencies"]["fixture_package"]["path"] = "different_package"
        self.write_lock()
        with self.assertRaisesRegex(ValueError, "Unexpected package location"):
            integration.verify()

    def test_changed_owned_fixture_is_rejected(self):
        (self.root / "fixture.json").write_text("different fixture")
        with self.assertRaisesRegex(ValueError, "fixture differs"):
            integration.verify()

    def test_relabelled_upstream_fixture_is_rejected(self):
        self.lock["fixtures"][0]["sha256"] = "0" * 64
        self.write_lock()
        with self.assertRaisesRegex(ValueError, "fixture differs"):
            integration.verify()

    def use_hosted_package(self):
        hosted = Path(self.temp.name) / "hosted packages/fixture_package-1.0.0"
        hosted.mkdir(parents=True)
        (hosted / "example.json").write_bytes((self.root / "fixture.json").read_bytes())
        (self.root / ".dart_tool/package_config.json").write_text(json.dumps({
            "packages": [{"name": "fixture_package", "rootUri": hosted.as_uri()}]
        }))
        self.lock["dependencies"]["fixture_package"] = {"source": "hosted", "version": "1.0.0"}
        self.write_lock()
        resolved = {"fixture_package": {"source": "hosted", "version": "1.0.0"}}
        mock = patch.object(integration, "resolved_packages", return_value=resolved)
        mock.start()
        self.addCleanup(mock.stop)
        return hosted, resolved

    def test_hosted_archive_needs_no_git_checkout(self):
        hosted, _ = self.use_hosted_package()
        integration.verify()
        self.assertEqual(integration.package_root("fixture_package"), hosted)

    def test_hosted_path_override_is_rejected(self):
        _, resolved = self.use_hosted_package()
        resolved["fixture_package"]["source"] = "path"
        with self.assertRaisesRegex(ValueError, "hosted dependency contract"):
            integration.verify()

    def test_hosted_version_drift_is_rejected(self):
        _, resolved = self.use_hosted_package()
        resolved["fixture_package"]["version"] = "2.0.0"
        with self.assertRaisesRegex(ValueError, "hosted dependency contract"):
            integration.verify()

    def test_changed_hosted_fixture_is_rejected(self):
        hosted, _ = self.use_hosted_package()
        (hosted / "example.json").write_text("changed fixture")
        with self.assertRaisesRegex(ValueError, "fixture differs"):
            integration.verify()


if __name__ == "__main__":
    unittest.main()
