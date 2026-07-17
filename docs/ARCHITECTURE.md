# Architecture

```text
completion hook
      │
      ▼
finish-inbox notify
      │  private lock + atomic rename
      ▼
local event queue
      │
      ▼
single menu bar manager
      │  reconcile + atomic state save
      ├──────────────► bounded processed-event window
      ▼
unread counts by display label
      │
      ▼
NSStatusItem UI
```

## Modules

- `FinishInboxCore` contains models, validation, private storage, mapping,
  locking, queue processing, and state transitions. It does not import AppKit.
- `FinishInbox` is the shared command entry point and menu bar manager. Release
  builds install a standalone CLI copy for shell commands; macOS launches the
  signed app-bundle copy through Launch Services for the visible status item.
- `scripts/` builds the app bundle, installs it for one user, verifies the
  archive, and uninstalls without deleting private data by default.

## Why a file queue

Completion hooks are short-lived processes. A durable file queue lets them
record an event even when the UI manager is not running. It also keeps the
system auditable and avoids a background network service, database daemon, or
privileged helper.

Each event is written to a private temporary file and atomically renamed into
the queue. The manager persists the new state before removing the event. If it
dies between those two actions, the retained event ID prevents double counting
after restart.

## Concurrency

One cross-process operation lock serializes notify, reconcile, and clear. A
second lifetime lock ensures there is at most one manager per state root.

Clear has an explicit order: queued events before the clear are reconciled and
then dismissed; events arriving after the clear remain unread.

## Bounded state

Processed event IDs exist only for retry deduplication. Entries older than seven
days are pruned, and the newest 10,000 entries are retained at most. This bounds
state size while preserving a practical retry window.

## Corruption handling

A missing state file initializes an empty state. A malformed existing state is
not treated as empty: processing stops and the original file is preserved for
diagnosis. Malformed queue events are moved to a private quarantine directory
without changing valid counts.

The exact transitions and invariants live in [PRODUCT_SPEC.md](PRODUCT_SPEC.md).
