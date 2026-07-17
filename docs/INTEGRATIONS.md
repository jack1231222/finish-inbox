# Integrations

FinishInbox accepts explicit local events. Any tool that can run a shell command
can integrate without granting FinishInbox access to its transcript or process
database.

## One-time project mapping

Run this from the project root:

```bash
~/.local/bin/finish-inbox map "Private display label"
```

Mappings use longest-prefix resolution, so commands in nested folders still
resolve to the project label. A missing mapping fails closed.

## Codex

Put this rule in a project `AGENTS.md` or your global Codex instructions:

```text
After a substantive task is complete and required verification has passed, run
~/.local/bin/finish-inbox notify before the final reply. If the current project
is not mapped, ask for a short private display label and run
~/.local/bin/finish-inbox map "<label>" first. A notifier failure must not hide
the task result.
```

This is intentionally a post-verification rule. A model merely saying “done” is
not treated as proof that tests or deliverables exist.

## Claude Code and other hook-based tools

Configure the tool's completion or stop hook to execute:

```bash
~/.local/bin/finish-inbox notify
```

Hook configuration formats change over time. Use the tool vendor's current
official hook documentation rather than copying an old JSON snippet from this
repository.

## Shell scripts and CI jobs

Call FinishInbox only after the command whose success matters:

```bash
if make test; then
  ~/.local/bin/finish-inbox notify --event-id "tests-${BUILD_ID}"
fi
```

Use a stable unique event ID when retries are possible. IDs must match
`[A-Za-z0-9_-]{1,128}` and are deduplicated within the documented retention
window.

## Failure handling

Once an event is safely queued, an app-launch warning must not cause an
integration to generate a new event ID and submit it again. Run
`finish-inbox doctor` if the menu bar manager does not appear.
