# Troubleshooting

## `No private project mapping exists`

FinishInbox deliberately refuses to display a folder name. Run this inside the
project and choose a short private label:

```bash
finish-inbox map "My App"
finish-inbox notify
```

## The count is durable but no menu bar item appears

Check the local state and installation without printing mapped paths:

```bash
finish-inbox status
finish-inbox doctor
```

Then run another `finish-inbox notify`. The event remains queued if macOS could
not launch the manager, so do not resubmit it with a new event ID merely because
the first launch showed a warning.

## A downloaded preview is blocked

The current archive is ad-hoc signed and not notarized. Prefer the source build.
If you trust the checked archive, follow Apple's
[unknown-developer guidance](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac).
FinishInbox does not run `xattr -d` or disable Gatekeeper.

## `state.json` is malformed

FinishInbox stops reconciliation and preserves the damaged file instead of
silently replacing your counts with an empty state. Keep a copy, repair or move
the file manually, then run `finish-inbox doctor`. Queued events remain in the
private `events` directory until state is valid again.

Do not paste config, state, event files, or private paths into a public issue.

## Uninstall

The default uninstaller keeps local mappings and unread state:

```bash
./scripts/uninstall.sh
```

Delete the private state as well only when you intend to:

```bash
./scripts/uninstall.sh --purge
```
