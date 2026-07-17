# FinishInbox v0.1 Product Specification

## Product boundary

FinishInbox is a quiet macOS menu bar inbox for completed coding-agent tasks.
It accepts explicit local completion events, groups unread completions by a
user-defined project label, and keeps them visible until the user dismisses
that project.

The first release deliberately does not inspect prompts, model responses,
terminal output, source files, or proprietary session databases. It does not
claim to prove that work is correct; it only displays completion events emitted
by a trusted local integration after that integration decides work is done.

## Done state

The release is ready when a new user can:

1. build or install the app without administrator access;
2. map a working directory to a private display label;
3. emit a completion event from a shell command;
4. see one persistent menu bar item per active project;
5. dismiss one project without losing later events;
6. uninstall the app while choosing whether to retain local state;
7. audit the source, release checksum, privacy boundary, and test evidence.

## Inputs and outputs

### Inputs

- A local command invocation.
- An optional explicit event ID matching `[A-Za-z0-9_-]{1,128}`.
- A project label supplied explicitly or resolved from a local mapping.
- A local JSON configuration file owned by the current user.

### Outputs

- A local event file containing only schema version, event ID, project label,
  and creation timestamp.
- A local state file containing only unread counts and a bounded deduplication
  window.
- A macOS menu bar label such as `My App · 2 done ✓`.
- Local diagnostic output that does not print project paths by default.

## Entities and identity keys

### CompletionEvent

- Identity key: `id`.
- Fields: `schemaVersion`, `id`, `project`, `createdAt`.
- The ID is immutable and is never silently rewritten.

### Project

- Identity key: the normalized display label stored in state.
- A project mapping maps a resolved directory path to that display label.
- Paths exist only in the private configuration file and never enter event or
  state files.

### ReminderState

- Identity key: one state root per local user or test environment.
- Fields: `schemaVersion`, `counts`, `processedEvents`.
- `counts[project]` is the unread completion count.
- `processedEvents[id]` stores the time at which an ID was accepted.

### Manager

- Identity key: the state root lock file.
- At most one live manager may reconcile a state root.

## State variables and derived state

- `queuedEvents`: valid JSON files waiting to be reconciled.
- `counts`: unread completions per project.
- `processedEvents`: bounded recent event IDs used for idempotency.
- `activeProjects`: projects whose unread count is greater than zero.
- `statusItems`: UI derived from `activeProjects`; it is not a source of truth.

## Initial state

- A missing state file means an empty, valid state.
- A missing config file means there are no mappings.
- A missing mapping is an error for implicit project resolution. The tool must
  not fall back to a disk directory name.
- A malformed state or config file is an error, not an empty state.

## Allowed actions and transitions

### `map <label>`

1. Resolve the current directory, including symlinks.
2. Validate and normalize the label.
3. Under a configuration lock, update the longest-prefix mapping table.
4. Save atomically with mode `0600` under a directory with mode `0700`.

### `notify`

1. Resolve a validated explicit label or a private directory mapping.
2. Validate or generate the event ID.
3. Under the operation lock, reject neither an already processed ID nor an
   already queued ID; both are idempotent success.
4. Write a `0600` temporary event and atomically rename it into the queue.
5. Ask macOS to launch the manager. Once the event is durable, launch failure
   is reported as a warning and does not cause the caller to resubmit it.

### Reconcile queued events

1. Acquire the manager lifetime lock before starting the refresh loop.
2. Under the operation lock, load a valid state.
3. Quarantine malformed events without changing valid state.
4. For each unseen event, increment exactly one project count and add the ID to
   the deduplication window.
5. Save the new state before deleting the event file.
6. Prune processed IDs older than seven days and then cap the newest IDs at
   10,000 entries.
7. Reconcile menu bar items from the persisted state.

### `clear <project>`

1. Acquire the operation lock.
2. Reconcile all events that were ordered before the clear operation.
3. Remove the selected project count and queued events for that project.
4. Save atomically.
5. Events ordered after the clear operation remain visible.

### `status` and `doctor`

- Read state and configuration without mutating them.
- Report counts, versions, permissions, and installation health.
- Do not print mapped disk paths unless an explicit verbose flag is used.

## Forbidden states

- A negative unread count.
- An active project with a zero count.
- Two live managers for the same state root.
- An event deleted before its updated state is durably saved.
- A missing or malformed mapping silently exposing a directory basename.
- Config, event, state, quarantine, or lock files readable by other users.
- Prompt text, model responses, source content, task titles, API keys, or full
  session logs in config, event, state, diagnostics, or release artifacts.
- An unbounded processed-event history.

## Invariants

1. **Ordered event accounting:** every successfully queued unique event is
   either represented by an unread count or was removed by a user clear action
   ordered after that event.
2. **Project isolation:** clearing one project never changes another project's
   count.
3. **Bounded idempotency:** a repeated ID within the retained seven-day / 10,000
   event window is counted at most once.
4. **Single writer:** only one manager may reconcile a state root at a time.
5. **Durability order:** state save succeeds before the matching queue file is
   removed.
6. **Fail-closed privacy:** implicit resolution never uses a directory name or
   persists a project path outside the private config file.
7. **Private storage:** state roots are `0700`; regular private files are
   `0600`.
8. **Derived UI:** the menu bar can be reconstructed entirely from state after
   restart.
9. **Bounded state:** processed event history never exceeds 10,000 entries.

## Preconditions and postconditions

### Notify preconditions

- The project label and event ID are valid.
- The state root can be prepared privately.
- Existing config and state files, when present, decode successfully.

### Notify postconditions

- The event exists durably in the queue or is already represented by the
  deduplication window.
- No private path or task body is present in the event.

### Clear postconditions

- The selected project has no count or queued event ordered before the clear.
- Other projects are byte-for-byte equivalent except for bounded-history
  pruning that is independent of project counts.

## Counterexamples and edge cases

- `a/b` and `ab` must not collapse into one event ID; invalid IDs are rejected.
- A project label containing newline, tab, control, or bidirectional override
  characters is rejected.
- A truncated `state.json` is preserved for diagnosis and must not be replaced
  with an empty state.
- A malformed queued event is quarantined; valid events still reconcile.
- A manager killed after saving state but before deleting an event counts the
  event once after restart because its ID is already processed.
- A clear racing with notify follows lock order: events before the clear are
  dismissed; events after the clear remain.
- A symlinked working directory resolves to the same mapping as its real path.
- More active projects than fit the menu bar are exposed through an overflow
  menu rather than creating unbounded status items.

## Test plan

- Unit tests: label normalization, longest-prefix mapping, missing and malformed
  config, ID validation, formatting, pruning, state decode failures.
- Storage tests: `0700/0600`, atomic save, quarantine, read-only directory,
  schema version rejection.
- Integration tests: concurrent notify, duplicate IDs, manager single-instance,
  notify/clear races, restart durability, bounded state.
- Packaging tests: universal binary slices, macOS deployment target, plist,
  strict ad-hoc signature, archive manifest, SHA-256.
- Real behavior: install into a clean temporary home, map a project, launch the
  real app, see the status item, click to clear, restart, and uninstall.

## Migration and rollback

- The public app uses its own Application Support directory and does not read
  private Codex files by default.
- An explicit migration command may import display mappings from the legacy
  local notifier, but it never copies them into the repository or release.
- The existing notifier stays installed until FinishInbox passes the real
  menu bar smoke test.
- Switching the user's completion wrapper requires a timestamped backup.
- Rollback restores that wrapper and relaunches the prior app; public source and
  release artifacts remain independent.
