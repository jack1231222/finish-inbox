import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('release_channel', ROOT / 'scripts/release-channel.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseChannelTests(unittest.TestCase):
    def test_current_historical_release(self):
        self.assertEqual(module.validate('v0.1.0-preview.1'), '0.1.0-preview.1')

    def test_free_tag_never_builds_historical_source(self):
        for tag in ['v0.2.0-free-preview.1', 'v0.1.0-free-preview.1', 'v0.1.0-free', 'v1.0.0-free']:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                module.validate(tag)

    def test_other_versions_and_malformed_tags_rejected(self):
        for tag in ['v0.2.0', 'v1.0.0', 'v0.1.1', 'v0.1.0', 'v0.1.00', 'v0.1.0-preview.1\n', 'v0.1.0/../../x', 'main']:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                module.validate(tag)

    def test_future_historical_patch_requires_matching_source_and_notes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / 'Sources/FinishInbox/Version.swift'
            source.parent.mkdir(parents=True)
            source.write_text('    static let current = "0.1.1"\n')
            with self.assertRaises(ValueError):
                module.validate('v0.1.1', root)
            notes = root / 'docs/releases/v0.1.1.md'
            notes.parent.mkdir(parents=True)
            notes.write_text('# Historical patch\n')
            self.assertEqual(module.validate('v0.1.1', root), '0.1.1')
            source.write_text('    static let current = "0.1.2"\n')
            with self.assertRaises(ValueError):
                module.validate('v0.1.1', root)

    def test_workflow_retains_two_independent_boundaries(self):
        workflow = (ROOT / '.github/workflows/release.yml').read_text()
        self.assertIn("      - 'v0.1.*'\n      - '!*-free*'", workflow)
        self.assertNotIn("      - 'v*'", workflow)
        self.assertIn("if: startsWith(github.ref_name, 'v0.1.') && !contains(github.ref_name, '-free')", workflow)
        self.assertLess(workflow.index('python3 scripts/release-channel.py'), workflow.index('swift test'))
        self.assertNotIn('--clobber', workflow)


if __name__ == '__main__':
    unittest.main()
