# Feedback and upgrade loop

FinishInbox uses Discussions for early feedback and support, and Issues for
work that is concrete enough to reproduce and verify.

[简体中文](FEEDBACK.zh-CN.md)

## Choose the right channel

| What you have | Where it belongs | Useful details |
| --- | --- | --- |
| An idea, workflow, or integration request | [Feedback discussion](https://github.com/jack1231222/finish-inbox/discussions/1) | The missed-completion problem and the tool that should emit the event |
| An installation or usage question | [Q&A](https://github.com/jack1231222/finish-inbox/discussions/categories/q-a) | macOS and FinishInbox versions, command used, and sanitized output |
| A reproducible defect | [Bug report](https://github.com/jack1231222/finish-inbox/issues/new?template=bug_report.yml) | Minimal steps, expected result, actual result, and privacy impact |
| A vulnerability | [Private security report](https://github.com/jack1231222/finish-inbox/security/advisories/new) | Impact and safe reproduction details; never disclose it publicly first |

Before starting a duplicate thread, react to or comment on an existing one.
That makes demand visible without splitting the evidence.

## How feedback reaches a release

1. A Discussion collects the workflow, alternatives, and demand.
2. Once the behavior and privacy boundary are clear, reproducible work moves to
   an Issue with an acceptance check.
3. A code change needs tests or equivalent real-behavior evidence.
4. The changelog and release notes record what shipped and which limitation
   remains.
5. The original Discussion or Issue is updated so contributors can verify the
   result.

Feedback influences priority, but it is not an automatic promise. Correctness,
local privacy, and a small maintenance surface remain release gates.

## Keep reports private by default

Do not post prompts, model responses, API keys, full logs, private paths,
`config.json`, `state.json`, or queued event files. Replace local labels and
paths with short placeholders before sharing output.
