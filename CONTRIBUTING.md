# Contributing

FinishInbox is intentionally small. Before adding a feature, explain which
missed completion or review workflow it fixes and why the change does not
require reading private task content.

## Development

```bash
swift test
./scripts/build-app.sh
```

Pull requests should include:

- a focused description;
- tests for state or concurrency changes;
- privacy impact, even when the answer is “none”;
- a real screenshot for visible UI changes;
- no personal paths, state files, prompts, or generated build output.

Do not weaken the invariants in `docs/PRODUCT_SPEC.md` without updating the
spec, tests, and migration notes in the same pull request.
