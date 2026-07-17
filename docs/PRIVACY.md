# Privacy

FinishInbox is local-only by design. The runtime contains no analytics client,
network uploader, account system, or cloud backend.

## Data it reads

- The current working directory, only to resolve a private display mapping.
- `HOME` and documented `FINISH_INBOX_*` settings used to select the app and
  private state root.
- Its own config, event queue, state, locks, and quarantine directory.

## Data it stores

- Directory-to-label mappings in the private config file.
- Project display labels and unread completion counts.
- Recent event IDs and timestamps for bounded deduplication.
- Malformed local event files moved into a private quarantine directory for
  diagnosis.

## Data it does not read or store

- prompts or model responses;
- source-code contents;
- terminal output;
- task titles or chat transcripts;
- API keys or unrelated environment variables;
- complete Codex, Claude Code, Cursor, or other agent session databases.

## On-disk protections

The default state root is:

```text
~/Library/Application Support/FinishInbox/
```

Directories are forced to POSIX mode `0700`. Config, state, queue, quarantine,
and lock files are forced to `0600`. Implicit project resolution fails closed:
an unmapped directory is never displayed using its disk basename.

Paths exist only in the private mapping file. Event and state files contain the
chosen display label, not the mapped path.

## Network behavior

The installed app and CLI make no network requests. Build, install-from-source,
and GitHub release workflows naturally contact package or hosting services only
when the user explicitly runs them.

## Limits

FinishInbox is not a macOS sandboxed App Store app. A process running as the
same local user can generally read that user's files, including FinishInbox
state. File permissions primarily protect against other non-privileged local
accounts and accidental disclosure.

Display labels can still be sensitive. Use short aliases that are safe to show
on a shared screen.

## Reporting a privacy problem

Do not post private paths or event files in a public issue. Follow
[SECURITY.md](../SECURITY.md) and share the smallest redacted reproduction.
