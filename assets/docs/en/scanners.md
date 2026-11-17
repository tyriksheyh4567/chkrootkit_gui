# Scanner arguments and directories

| Tool | Arguments used by the application | Scope |
| --- | --- | --- |
| chkrootkit | Default checks; `-r <root>` for an alternate scan directory | Files under the chosen filesystem root; process checks use the running kernel |
| rkhunter | `--check --skip-keypress --report-warnings-only --nocolors` | Running system; modern versions have no supported alternate-root option |
| unhide | `-u -H quick` | Running processes via /proc, ps and system calls; port checks require unhide-tcp |
| Lynis | `audit system --quick --no-colors` | Running system configuration and security audit |

Version checks use `chkrootkit -V`, `unhide -V`, or `--version`. Failure to read a version without root does not make an installed executable unavailable.

## Working directory

The default working directory is the real executable's directory after resolving symlinks. Thus `/usr/bin/chkrootkit` pointing to `/usr/lib/chkrootkit/chkrootkit` runs in `/usr/lib/chkrootkit`, where relative helper binaries can be found. A custom working directory must exist. It affects process execution separately from the scan root.

An alternate chkrootkit scan root must be an existing absolute directory; `~/` is expanded to the invoking user's home. It is passed using `-r` without a shell. rkhunter's old rootdir feature was removed, Unhide checks the live kernel, and Lynis does not provide complete alternate-root coverage. These tools therefore use the running system in this application.

## Permissions

chkrootkit, rkhunter and unhide require root. Lynis permits a limited audit without it. Changing the executable location does not change required privileges. seatd handles compositor device access; pkexec and a polkit agent handle administrative authorization.

## Primary documentation

- [chkrootkit FAQ](https://chkrootkit.org/faq/)
- [rkhunter rootdir feature history](https://sourceforge.net/p/rkhunter/feature-requests/42/)
- [Unhide manual](https://github.com/YJesus/Unhide/blob/master/man/unhide.8)
- [Lynis source](https://github.com/CISOfy/lynis)
- [Lynis alternate root limitations](https://github.com/CISOfy/lynis/discussions/1468)
- [seatd](https://github.com/kennylevinsen/seatd)
