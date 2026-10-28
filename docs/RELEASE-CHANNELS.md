# Release channels

## Historical open-source builds

The `Release` workflow handles only `v0.1.*` tags and excludes tags containing
`-free`. Its job repeats this boundary, then `scripts/release-channel.py` checks
that the tag exactly matches `Sources/FinishInbox/Version.swift` and has release
notes in `docs/releases/` before any build begins.

A future historical patch needs its own real source change, matching version,
and notes. Do not change the historical version to `0.2` to make a Free tag pass.
Existing `gh release create` behavior is retained: the workflow does not replace
an existing release or overwrite its assets.

## Binary-only Free releases

Tags such as `v0.2.0-free-preview.1` belong to the independently built Free app.
The public historical source is not its build input. This repository must not
build or automatically upload replacement Free binaries from that source.

Free binaries are built and verified locally. Only the approved application
archive, checksum, and public instructions are uploaded. Current Free source,
private project files, account material, test state and logs remain local.
The authorized publisher checks the existing release and asset identity before
an update; unknown outcomes are reconciled before retrying.

GitHub's automatically generated source archives refer to the public repository
at the tag; they are historical source, not the Free app's implementation.

## Validation and activation

Run `python3 -m unittest discover -s scripts -p 'test_release_channel.py'`.
Normal branch/PR CI also runs this boundary check and continues to test the
historical source at its unchanged version.

A local workflow edit does not change GitHub behavior. After a separately
authorized review and push, future tags use the workflow at their tagged commit.
An existing failed run remains historical; rerunning it uses the old workflow
and does not prove the fix. Do not move or recreate an existing release tag to
hide that failure. The already published Free assets are independent of it.
