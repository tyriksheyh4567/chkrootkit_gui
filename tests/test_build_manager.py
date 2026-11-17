"""Argument validation and terminal UI interaction without running real builds."""
import asyncio
import importlib.util
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'tools'))
from release_notes import release_notes

HAS_TEXTUAL = importlib.util.find_spec('textual') is not None
if HAS_TEXTUAL:
    from build_manager import BuildManager, build_command
    from textual.widgets import Button, Input, Static


class ReleaseNotesTest(unittest.TestCase):
    def test_version_and_section_boundaries(self):
        text = '# Changes\n## [1.0.0] - today\nNew feature.\n## [0.9.0]\nOld.\n'
        self.assertEqual(release_notes('1.0.0', 'version: 1.0.0+1', text), 'New feature.\n')
        for version in ('1.0.1', '../1.0', '1.0.0; echo BAD'):
            with self.assertRaises(ValueError):
                release_notes(version, 'version: 1.0.0+1', text)


@unittest.skipUnless(HAS_TEXTUAL, 'run with .venv-tui/bin/python after make .venv-tui/.ready')
class BuildManagerTest(unittest.IsolatedAsyncioTestCase):
    def values(self):
        return dict(target='app', mode='release', package='deb', jobs='4',
                    flutter='/path with space/flutter', output='build/packages', bundle='', appimage='appimagetool')

    def test_argument_validation_and_literal_paths(self):
        values = self.values()
        command = build_command(values)
        self.assertIn('/path with space/flutter', command)
        for field, value in [('jobs', '0'), ('jobs', '257'), ('jobs', '-1'), ('jobs', '2.5'),
                             ('mode', 'debug'), ('target', 'service'), ('package', 'unknown')]:
            bad = dict(values, **{field: value})
            with self.assertRaises(ValueError):
                build_command(bad)

    async def test_form_validation_and_fake_build_log(self):
        app = BuildManager()
        async with app.run_test(size=(100, 40)) as pilot:
            app.query_one('#jobs', Input).value = '0'
            await pilot.click('#build')
            self.assertIn('1 to 256', str(app.query_one('#status', Static).render()))
            self.assertFalse(app.query_one('#build', Button).disabled)
            await app.run_build([sys.executable, '-c', 'print("fixture build output")'])
            self.assertIn('complete', str(app.query_one('#status', Static).render()))
            await app.run_build([sys.executable, '-c', 'raise SystemExit(7)'])
            self.assertIn('7', str(app.query_one('#status', Static).render()))

    async def test_cancel_stops_child_and_resets_controls(self):
        app = BuildManager()
        async with app.run_test(size=(80, 30)):
            task = asyncio.create_task(app.run_build([sys.executable, '-c', 'import time; time.sleep(30)']))
            for _ in range(100):
                if app.process:
                    break
                await asyncio.sleep(.01)
            self.assertIsNotNone(app.process)
            app.action_cancel()
            await asyncio.wait_for(task, 5)
            self.assertIsNone(app.process)
            self.assertFalse(app.query_one('#build', Button).disabled)


if __name__ == '__main__':
    unittest.main()
