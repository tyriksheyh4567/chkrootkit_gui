# chkrootkit GUI 1.0.0 user guide

The application brings local GNU/Linux checks together and helps review their output. Findings are indicators for an administrator to investigate. A clean summary cannot rule out infection, and a warning requires checking its cause.

## Run your first scan

1. Open **Tools** and install chkrootkit, rkhunter, unhide or Lynis using your distribution's repositories. Keep the complete tool distribution, including its helper files.
2. Open **Scan**, choose a tool and check that its executable was found.
3. For chkrootkit, set the **Scan directory**. `/` selects the current system. `/mnt/system` can be the root of an already mounted system. Process checks still use the running kernel. The other tools check the running system.
4. Click **Start scan**. A polkit dialog asks permission to launch the separate privileged service. The password is handled by polkit.
5. Wait for completion or click **Stop**. A scan is limited to ten minutes.
6. Review **Summary**, **Output** and **Findings**, including the exit code, launch errors and skipped tests.
7. Use **Export .log** and provide the full path to a new file. Existing files are not overwritten.

## Permissions and launch options

chkrootkit, rkhunter and unhide require root, including when installed in `~/.local/bin`. Lynis supports a limited unprivileged audit. Advanced options allow changing the process working directory. The default is the real executable's directory, after resolving symlinks.

**Keep the privileged service running** reuses an authorized session until the app closes. Disable it to stop the service after every operation. The next operation asks for authorization again. No system daemon is installed for automatic startup.

Allowing a service owned by a regular user is intended for development. For normal use, install a package in a root-owned system directory.

seatd provides a compositor with device access. Administrative authorization requires polkit, pkexec, D-Bus and a running polkit authentication agent.

## Model analysis

Open **API analysis** in **Findings**. Create a database password or unlock existing databases. Choose GPTunnel or OpenAI compatible, enter a server URL, model and API key. Use `https://gptunnel.ru/v1` for GPTunnel.

Review the log before submitting: the entire output is sent to the selected server and may contain file names, user names and addresses. A submission may incur provider charges. The Markdown response requires manual verification. Links are copied to the clipboard; remote images are not loaded automatically.

Saving the key is optional. **Save API** stores only the URL, model and provider unless key storage is enabled. The key field explains whether a key has been loaded. HTTP 401 generally concerns the key or authorization; a positive account balance does not authenticate a request.

## Appearance and language

Use the top bar to choose Russian or English, light/dark/system theme, and an accent color. Preferences persist between launches. Manual colors work without matugen. Scanner output and existing model responses keep their original language.

## Troubleshooting

- Check the tool installation and helper files.
- For authorization errors, check the session's polkit agent and D-Bus.
- Keep chkrootkit's working directory automatic; a custom directory must contain helpers such as `chkproc` and `strings-static`.
- Ensure the scan directory exists. Paths are passed as separate arguments without a shell.
- Export the log and include the scanner version and exit code when requesting help. Remove personal information before sharing it.
