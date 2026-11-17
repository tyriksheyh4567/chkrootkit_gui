# Changelog

## [1.0.0] - 2026-11-17

### Interface and documentation

- Russian and English interface with saved language, theme and accent preferences.
- Offline user guide, scanner arguments, threat reference, storage and build documentation inside the application.
- Findings represent the latest completed scan; complete output can be exported as `.log`.
- Markdown rendering for model responses with selectable text and safe link handling.
- A separate scan-directory control for chkrootkit, using its `-r` option. Advanced process working-directory settings remain available.

### Scanning and analysis

- Separate C++ privileged service launched through pkexec, with optional session reuse and a fixed set of supported operations.
- Correct resolution of scanner symlinks and helper directories; required root access for chkrootkit, rkhunter and unhide.
- OpenAI-compatible and GPTunnel API support, explicit key-loading status and provider-specific authorization.
- Separate SQLite profile and request-cache databases; AES-256-GCM encrypted payloads, password-state-aware dialogs and confirmed database deletion.

### Build and distribution

- Textual build manager with validated options, streaming logs and cancellation; Makefile shortcuts and retained command-line backend.
- `.deb`, `.rpm`, `.AppImage` and `.pkg.tar.zst` packaging; corrected Arch package metadata and package-reader regression checks.
- Manually triggered GitHub build/release workflow. Release descriptions use this changelog section.
- Project description prepared from the supplied school templates in `presentation/описание.docx`.

### Limitations

- Scanner warnings and model responses require manual verification. They do not establish infection or guarantee a clean system.
- Alternate-root scanning is offered only for chkrootkit; live process checks still use the host kernel.
- AppImage requires system GTK, polkit and SQLite. Packages should be checked on their target distributions before publication.
