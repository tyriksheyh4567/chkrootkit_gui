# Data storage

API profiles are stored in `$XDG_CONFIG_HOME/chkrootkit_gui/api.db` (default `~/.config/chkrootkit_gui/api.db`). Responses are cached separately in `$XDG_CACHE_HOME/chkrootkit_gui/requests.db` (default `~/.cache/chkrootkit_gui/requests.db`). Theme and language preferences are stored unencrypted in `appearance.json`.

API profile contents and cached responses use AES-256-GCM encryption. PBKDF2-HMAC-SHA256 derives the key from a password with 210,000 iterations and a random salt. Neither the password nor the derived key is saved to disk. SQLite structure, salt, verification metadata, hashes and cache timestamps remain visible; record payloads are encrypted.

The API key is saved only when explicitly enabled. The cache stores up to 100 responses for up to seven days. Source logs and API keys are excluded from the cache. Exported `.log` files are plain text and should be handled as potentially sensitive.

The password dialog reflects the storage state: new password creation, unlock, migration of old records, or a damaged-database message. Damaged databases are never silently replaced. Back them up before attempting recovery.

**Delete both databases…** requires confirmation and removes profiles, keys, cached responses, encryption metadata and SQLite WAL/SHM/journal sidecars. Exported logs remain. Deletion does not guarantee physical erasure of backups, filesystem snapshots or SSD blocks. A lost password cannot be recovered through the app.
