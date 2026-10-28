# FinishInbox Free

把 Codex 的任务完成与待回复提醒留在 macOS 菜单栏，方便你回来处理。

## [⬇ 下载免费公证版（macOS）](https://github.com/jack1231222/finish-inbox/releases/download/v0.2.0-free-preview.1/FinishInbox-Free-0.2.0-notarized-macos.zip)

**Apple 公证已通过 · 免费使用 · 无订阅 · 无需编译或安装 Python**

推荐下载的文件名：`FinishInbox-Free-0.2.0-notarized-macos.zip`。

[SHA-256 校验文件](https://github.com/jack1231222/finish-inbox/releases/download/v0.2.0-free-preview.1/FinishInbox-Free-0.2.0-notarized-macos.zip.sha256) · [下载页与版本说明](https://github.com/jack1231222/finish-inbox/releases/tag/v0.2.0-free-preview.1) · [使用与隐私说明](FREE-EDITION.md)

### 打开即用

1. 下载上方 ZIP 并解压，将 **FinishInbox Free.app** 拖到“应用程序”。
2. 打开应用，选择是否启用本地 Codex 监听。
3. 在菜单栏查看完成计数与待回复列表；从 **F✓** 菜单暂停监听或退出。

当前为免费预览版，使用 Developer ID 签名并附有 Apple 公证票据。macOS 可能显示普通的互联网下载确认；应用不移除隔离标记、不修改系统安全设置。

包含 Apple Silicon 和 Intel 两种架构，部署目标为 macOS 13 及以上。已在 **macOS 27 / Apple Silicon** 实测下载与启动；Intel 和旧系统未作实机验证。

### 隐私与源码

应用在本机处理 Codex 事件与待回复对话元数据，不上传数据，无云端统计。当前免费版只提供编译后的应用，源码不公开；发布者姓名仅存在于签名证书中，不附带其他个人资料、聊天或本机配置。

---

## 历史版本：仅供查阅

**旧安装包与本页下方源码均为历史版本，不是上方的免费公证版。** 下载页中标为“历史／未公证”的附件不推荐普通用户下载。GitHub 自动生成的 **Source code (zip / tar.gz)** 也是历史开源代码，不能替代当前应用包。

<details>
<summary>展开历史开源版 0.1.0 的介绍与源码安装方法</summary>

# FinishInbox

[![CI](https://github.com/jack1231222/finish-inbox/actions/workflows/ci.yml/badge.svg)](https://github.com/jack1231222/finish-inbox/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/jack1231222/finish-inbox?include_prereleases)](https://github.com/jack1231222/finish-inbox/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-2ea44f.svg)](LICENSE)

![FinishInbox social preview](assets/finish-inbox-social-preview.png)

**A quiet macOS menu bar inbox for completed coding-agent tasks.**

FinishInbox turns explicit completion events from Codex, Claude Code, or any
local script into persistent unread counters. Each project stays visible in the
menu bar until you click it clear.

```text
Client App · 2 done ✓
```

![FinishInbox showing two unread completions in the macOS menu bar](assets/finish-inbox-menubar.png)

No prompt scanning. No response history. No cloud service.

If FinishInbox solves this problem for you, a star helps more coding-agent
users find it. Have an integration request? [Tell me what should come
next](https://github.com/jack1231222/finish-inbox/discussions/1).

[简体中文](README.zh-CN.md)

## Why this exists

Desktop notifications disappear. Terminal tabs get buried. When several agents
finish at once, it is easy to forget which project still needs review.

FinishInbox keeps one small, durable signal:

- completion events accumulate by project;
- repeated event IDs are deduplicated;
- clicking a project marks only that project as read;
- counts survive app restarts;
- private task text never enters the state file.

FinishInbox does not decide whether an agent's work is actually correct. Your
integration emits the event after its own verification step.

## Quick start

### Build and install from source

Requirements: a Swift 6 toolchain (Xcode 16 or later). The built app targets
macOS 13 or later.

```bash
git clone https://github.com/jack1231222/finish-inbox.git
cd finish-inbox
./scripts/install.sh
```

Map the current directory to the label you want to see:

```bash
~/.local/bin/finish-inbox map "Client App"
```

Send a completion event:

```bash
~/.local/bin/finish-inbox notify
```

Useful checks:

```bash
~/.local/bin/finish-inbox status
~/.local/bin/finish-inbox doctor
```

### Downloaded preview builds

The current preview is ad-hoc signed, not Apple-notarized. macOS may block a
downloaded build until you explicitly allow it in **System Settings → Privacy &
Security**. Building from source is the smoother path until a notarized release
is available. FinishInbox never removes macOS quarantine attributes for you.

If you use the preview archive, download its matching `.sha256` file and verify
it before opening `install.command`:

```bash
shasum -a 256 -c FinishInbox-v0.1.0-preview.1.zip.sha256
```

See the [preview release](https://github.com/jack1231222/finish-inbox/releases/tag/v0.1.0-preview.1)
and Apple's [unknown-developer guidance](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac).

## Codex integration

Add this rule to a project or global `AGENTS.md` after installing FinishInbox:

```text
After a substantive task is complete and the required verification has passed,
run ~/.local/bin/finish-inbox notify before the final reply. If this directory
has not been mapped yet, ask for a short private display label and run
~/.local/bin/finish-inbox map "<label>" first. A notifier failure must not hide
the task result.
```

For other tools, call `finish-inbox notify` from their completion or stop hook.
See [integration notes](docs/INTEGRATIONS.md).

## Privacy model

Runtime data stays in:

```text
~/Library/Application Support/FinishInbox/
```

FinishInbox stores only:

- your private directory-to-label mappings;
- project labels and unread counts;
- bounded recent event IDs and timestamps.

It does not read or store prompts, model responses, source files, terminal
output, API keys, or complete agent session logs. Private directories use mode
`0700`; config and state files use mode `0600`.

Read the full [privacy notes](docs/PRIVACY.md).

## Commands

```text
finish-inbox map <label>       Map the current directory
finish-inbox unmap             Remove the current directory mapping
finish-inbox notify            Record one completion
finish-inbox clear <project>   Clear a project counter
finish-inbox status            Show unread totals without project paths
finish-inbox doctor            Check installation and private permissions
finish-inbox preview           Print a label without changing state
```

Run `finish-inbox help` for the exact options in your installed version.

## Feedback and upgrades

- [Ideas and integration requests](https://github.com/jack1231222/finish-inbox/discussions/1)
  stay open for comments and voting.
- [Questions and setup help](https://github.com/jack1231222/finish-inbox/discussions/categories/q-a)
  belong in Q&A.
- [Reproducible bugs](https://github.com/jack1231222/finish-inbox/issues/new?template=bug_report.yml)
  become tracked issues.
- Security reports use the [private advisory form](https://github.com/jack1231222/finish-inbox/security/advisories/new).

See how feedback becomes a tested release in the
[feedback and upgrade loop](docs/FEEDBACK.md).

## Build and test

```bash
swift test
./scripts/integration-stress.py
./scripts/build-app.sh
./scripts/app-launch-smoke.py
./scripts/package-release.sh
```

The core test suite covers mapping resolution, input validation, private file
permissions, durable event ordering, idempotency, corrupt-state handling,
bounded history, project isolation, restart recovery, and the deterministic
menu-bar visible/overflow projection. The app-launch smoke test additionally
exercises real manager processes, single-manager locks, and project-isolated
clearing across two independent state roots. It does not replace the release
check for clearing projects through the same manager's real AppKit status-item
click path.

See [architecture](docs/ARCHITECTURE.md) and the explicit
[state invariants](docs/PRODUCT_SPEC.md). Common recovery steps are in
[troubleshooting](docs/TROUBLESHOOTING.md).

## Release status

`v0.1.0-preview.1` is a technical preview. The repository and release pipeline
are public and reproducible; downloaded binaries remain unnotarized until a
Developer ID signing identity is available. This limitation is reported in
release metadata instead of being hidden by an unsafe quarantine-removal
installer.

## Contributing

Small, focused changes are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md)
before opening a pull request. Security reports belong in the private channel
described in [SECURITY.md](SECURITY.md), not in a public issue.

MIT License.

</details>
