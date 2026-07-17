## Summary

Describe the behavior changed and why.

## Verification

- [ ] `swift test`
- [ ] `scripts/build-app.sh 0.1.0-preview.1` (for packaging or app changes)
- [ ] README image references and privacy scan pass
- [ ] New or changed behavior has tests

## Privacy and release checks

- [ ] No prompts, responses, source content, credentials, full logs, or private paths are persisted or exposed
- [ ] Diagnostics hide mapped paths unless explicitly requested
- [ ] Release artifacts remain ad-hoc signed and `NOT_NOTARIZED`; this PR does not claim Developer ID signing or notarization
- [ ] Documentation matches the observed behavior
