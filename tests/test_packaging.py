"""Package-reader regression tests; no installation or host bundle mutation."""
import pathlib
import shutil
import subprocess
import tempfile
import unittest

PROJECT = pathlib.Path(__file__).resolve().parents[1]


class PackagingTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='rootkit packaging ')
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        shutil.copy(PROJECT / 'build.sh', self.root)
        shutil.copy(PROJECT / 'pubspec.yaml', self.root)
        shutil.copytree(PROJECT / 'tools', self.root / 'tools')
        shutil.copytree(PROJECT / 'packaging', self.root / 'packaging')
        self.bundle = self.root / 'fixture bundle'
        self.bundle.mkdir()
        for name in ('chkrootkit_gui', 'rootkit_guard_service'):
            shutil.copy('/bin/true', self.bundle / name)

    def build(self, kind, *extra):
        result = subprocess.run([
            'bash', str(self.root / 'build.sh'), '--bundle-dir', str(self.bundle),
            '--package', kind, '--jobs', '2', *extra,
        ], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return self.root / 'build/packages'

    @unittest.skipUnless(all(shutil.which(x) for x in ('pacman', 'bsdtar', 'zstd')), 'Arch tools missing')
    def test_arch_metadata_readable_by_pacman(self):
        output = self.build('pkg.tar.zst')
        self.build('pkg.tar.zst')  # Existing artifact can be replaced.
        artifact = next(output.glob('*.pkg.tar.zst'))
        result = subprocess.run(['pacman', '-Qip', str(artifact)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        listing = subprocess.check_output(['bsdtar', '-tf', str(artifact)], text=True).splitlines()
        self.assertIn('.PKGINFO', listing)
        self.assertNotIn('./.PKGINFO', listing)
        self.assertIn('opt/chkrootkit_gui/rootkit_guard_service', listing)
        self.assertFalse(list((self.root / 'build').glob('package-work.*')))

    @unittest.skipUnless(all(shutil.which(x) for x in ('rpmbuild', 'rpm')), 'RPM tools missing')
    def test_rpm_metadata_and_payload(self):
        artifact = next(self.build('rpm').glob('*.rpm'))
        result = subprocess.run(['rpm', '--dbpath', str(self.root / 'rpmdb'), '-qpl', str(artifact)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('/opt/chkrootkit_gui/rootkit_guard_service', result.stdout)

    @unittest.skipUnless(shutil.which('dpkg-deb'), 'dpkg-deb missing')
    def test_deb_metadata_and_payload(self):
        artifact = next(self.build('deb').glob('*.deb'))
        subprocess.run(['dpkg-deb', '--info', str(artifact)], check=True, capture_output=True)
        subprocess.run(['dpkg-deb', '--extract', str(artifact), str(self.root / 'extract')], check=True)
        self.assertTrue((self.root / 'extract/opt/chkrootkit_gui/rootkit_guard_service').is_file())

    def test_appdir_layout(self):
        # Validate AppDir input independently of appimagetool/FUSE availability.
        tool = self.root / 'check-appdir'
        tool.write_text('''#!/bin/sh
set -eu
[ -x "$1/AppRun" ]
[ -f "$1/com.example.chkrootkit_gui.desktop" ]
[ -f "$1/rootkit-guard.svg" ]
[ -L "$1/.DirIcon" ]
grep -q 'Icon=rootkit-guard' "$1/com.example.chkrootkit_gui.desktop"
[ -x "$1/usr/lib/chkrootkit_gui/rootkit_guard_service" ]
''')
        tool.chmod(0o755)
        self.build('appimage', '--appimage-tool', str(tool))


if __name__ == '__main__':
    unittest.main()
