# Build and release

Building requires Linux, Flutter 3.47.1 with Dart 3.13.1 or a compatible SDK, CMake, Ninja, a C++17 compiler and GTK 3 development libraries. Python dependencies are used only by the TUI.

- `make tui` or `./build.sh`: open the build manager. The first run creates `.venv-tui` and installs Textual 8.2.8. Python 3.10+ with venv and pip is required.
- `make build`: build the release application and service.
- `make service`: build the C++ service alone.
- `make package FORMAT=deb`: build and package the app. Other formats: `rpm`, `appimage`, `pkg.tar.zst`, `all`.
- `make build FLUTTER=/path/to/flutter MODE=debug JOBS=4`: override build options.

The TUI provides target, mode, format, job count and path fields, validates settings, streams build output and cancels the process group. Tab moves focus, Ctrl+B builds, Ctrl+K cancels and Ctrl+Q quits. Scroll the form to see additional fields.

Use `./build.sh --help` for automation. `--bundle-dir` packages an existing bundle. The backend checks the tools required by each format: dpkg-deb, rpmbuild, bsdtar/zstd and appimagetool. AppImage requires system GTK, polkit and SQLite; portability depends on the target environment.

Run GitHub Actions manually using **Actions → Release → Run workflow**. The version must match pubspec.yaml and a CHANGELOG.md section. Publication is a separate option; the default stores build artifacts only. Release notes are taken from the changelog. Check the packages on target distributions before publishing a public release.
