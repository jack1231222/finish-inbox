# Release checklist

A green build is only one signal. A release is ready when the source, produced
archive, installed app, and public metadata all agree.

## Source gates

- [ ] `swift test` passes without skipped invariant tests.
- [ ] `scripts/integration-stress.py` passes against the candidate CLI.
- [ ] `swift build -c release` passes.
- [ ] `scripts/privacy-scan.sh` reports no private username, home path, prompt,
      response, config, state, or legacy binary in tracked/release files.
- [ ] README commands match `finish-inbox help`.
- [ ] Current version appears consistently in plist, changelog, package output,
      tag, and release notes.
- [ ] `Sources/FinishInbox/Version.swift` equals the release tag; the build
      script rejects a mismatch.

## Artifact gates

- [ ] `scripts/build-app.sh` creates `FinishInbox.app` from the current source.
- [ ] The standalone `finish-inbox` CLI executes outside the app bundle and
      launches the bundle through Launch Services.
- [ ] `lipo -info` proves both `arm64` and `x86_64` slices, or the release is
      explicitly architecture-limited.
- [ ] `otool -l` proves the intended minimum macOS version.
- [ ] `plutil -lint` passes for the bundled plist.
- [ ] `codesign --verify --deep --strict` passes for the complete bundle.
- [ ] The manifest records source revision, binary hash, archive hash, signing
      identity, notarization status, supported architecture, and deployment
      target.
- [ ] Archive contents match the allowlist; no local config, state, build cache,
      username, absolute home path, or legacy executable is present.

## Behavior gates

- [ ] Install into a clean temporary home without administrator access.
- [ ] Map a project and confirm an unmapped project fails without revealing its
      directory basename.
- [ ] Emit one event, a duplicate ID, and concurrent events for two projects.
- [ ] Confirm restart preserves counts and service/state-layer clear affects only
      one project.
- [ ] Confirm corrupt state is preserved and not overwritten as empty.
- [ ] Confirm config, events, state, locks, and quarantine are `0600`, and their
      directories are `0700`.
- [ ] Launch the real App bundle, inspect the real menu bar label, click it, and
      verify the matching count disappears.
- [ ] `scripts/app-launch-smoke.py` proves two state roots keep two independent
      Launch Services managers, duplicate launches preserve single-manager
      locking per root, and clearing one project in one root leaves the other
      root's project unchanged. This does not replace the same-manager
      status-item click check above.
- [ ] Run uninstall once while retaining data and once in an isolated home with
      `--purge`; both are idempotent.

## Public-release gates

- [ ] GitHub description, topics, README hero, license, security policy,
      contribution guide, issue templates, and release notes are visible.
- [ ] Release assets and SHA-256 file download successfully and match locally.
- [ ] Preview builds are marked pre-release.
- [ ] A build without Developer ID signing and notarization says so prominently;
      no script silently removes the quarantine attribute.
- [ ] A stable binary release additionally passes `spctl --assess` and
      `stapler validate` on a freshly downloaded artifact.
