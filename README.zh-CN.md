# Historical Chinese guide

The current app is **English only**, including its menus, prompts, and bundled instructions.

[Download the English notarized app](https://github.com/jack1231222/finish-inbox/releases/download/v0.2.1-free-preview.1/FinishInbox-Free-0.2.1-English-notarized-macos.zip) · [Current English guide](README.md)

<details>
<summary>Historical Chinese documentation for version 0.2.0</summary>

# FinishInbox Free

[English · 默认英文首页](README.md)

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

![FinishInbox 项目预览图](assets/finish-inbox-social-preview.png)

**把已经完成的 AI 编程任务留在 macOS 菜单栏，等你看完再清。**

Codex、Claude Code 或本地脚本明确上报完成事件后，FinishInbox 会按项目累计未读数：

```text
客户 App · 2 完成 ✓
```

![FinishInbox 在 macOS 菜单栏显示两个未读完成事件](assets/finish-inbox-menubar.png)

它不扫提示词，不读回复，也不联网。

如果这个小工具也解决了你的问题，点一个 Star，能让更多 Agent 用户看到它。
想接入别的工具，可以到 [Ideas 讨论](https://github.com/jack1231222/finish-inbox/discussions/1) 留言。

[English](README.md)

## 它解决什么问题

系统通知一闪就没，终端窗口一多也容易漏。几个任务同时跑的时候，我真正想知道的是：还有哪些项目已经做完、但我没回去看。

FinishInbox 只管这件事：

- 同一项目的完成事件累计成一个未读数；
- 重复事件不会反复计数；
- 点击哪个项目，只清哪个项目；
- App 重启后计数还在；
- 状态文件里没有任务正文。

它不会替你判断工作是否真的正确。应该由 Codex、Hook 或脚本在完成验证之后再发事件。

## 安装

目前最稳的方式是从源码安装。构建需要 Swift 6 工具链（Xcode 16 或更高版本），
生成的 App 支持 macOS 13 或更高版本。

```bash
git clone https://github.com/jack1231222/finish-inbox.git
cd finish-inbox
./scripts/install.sh
```

进入项目目录，给它设一个只在本机保存的显示名：

```bash
~/.local/bin/finish-inbox map "客户 App"
```

测试一次完成提醒：

```bash
~/.local/bin/finish-inbox notify
```

排查安装状态：

```bash
~/.local/bin/finish-inbox status
~/.local/bin/finish-inbox doctor
```

## 关于下载版

当前预览版只有临时签名，还没有 Apple Developer ID 公证。直接下载 App 时，macOS 可能会拦截，需要到“系统设置 → 隐私与安全”里手动允许。等正式签名具备后，再把下载版升级成无警告安装。

项目不会为了省这一步，偷偷帮用户移除系统隔离标记。

如果使用下载包，请同时下载对应的 `.sha256` 文件，先校验再打开
`install.command`：

```bash
shasum -a 256 -c FinishInbox-v0.1.0-preview.1.zip.sha256
```

下载入口见 [v0.1.0-preview.1 预览版](https://github.com/jack1231222/finish-inbox/releases/tag/v0.1.0-preview.1)，
macOS 拦截处理见 [Apple 官方说明](https://support.apple.com/zh-cn/guide/mac-help/mh40616/mac)。

## 接到 Codex

安装后，把下面规则放进项目或全局 `AGENTS.md`：

```text
完成实质任务并通过必要验证后，在最终回复前运行
~/.local/bin/finish-inbox notify。如果当前目录还没有映射，先向用户要一个
简短的私有显示名，再运行 ~/.local/bin/finish-inbox map "<显示名>"。
提醒失败不能遮住任务结果。
```

其他 Agent 只要能在完成时执行 shell 命令，也可以调用 `finish-inbox notify`。配置思路见 [集成说明](docs/INTEGRATIONS.md)。

## 隐私边界

本地数据放在：

```text
~/Library/Application Support/FinishInbox/
```

只保存：

- 工作目录和显示名的本机映射；
- 项目显示名和未读数；
- 有上限的近期事件 ID、时间。

不会读取或保存提示词、模型回复、源码、终端输出、API Key 和完整会话日志。目录权限为 `0700`，配置和状态文件为 `0600`。

细节见 [隐私说明](docs/PRIVACY.md)。

## 常用命令

```text
finish-inbox map <显示名>       映射当前目录
finish-inbox unmap              删除当前目录映射
finish-inbox notify             记录一次完成
finish-inbox clear <项目>       清除项目计数
finish-inbox status             查看未读汇总，不显示路径
finish-inbox doctor             检查安装和文件权限
finish-inbox preview            只预览文案，不改状态
```

## 意见反馈与版本升级

- [功能想法和接入需求](https://github.com/jack1231222/finish-inbox/discussions/1)：可以评论、补充和投票；
- [安装与使用问题](https://github.com/jack1231222/finish-inbox/discussions/categories/q-a)：放到 Q&A；
- [能够复现的 Bug](https://github.com/jack1231222/finish-inbox/issues/new?template=bug_report.yml)：进入 Issue 跟踪；
- 安全问题通过[私密漏洞表单](https://github.com/jack1231222/finish-inbox/security/advisories/new)提交。

反馈如何进入后续版本，见[反馈与升级流程](docs/FEEDBACK.zh-CN.md)。

## 开发验证

```bash
swift test
./scripts/integration-stress.py
./scripts/build-app.sh
./scripts/app-launch-smoke.py
./scripts/package-release.sh
```

测试覆盖映射、输入校验、私有权限、事件落盘顺序、幂等、损坏状态、有界历史、项目隔离和重启恢复。状态约束写在 [产品规格](docs/PRODUCT_SPEC.md)，代码结构见 [架构说明](docs/ARCHITECTURE.md)，常见问题见 [排查说明](docs/TROUBLESHOOTING.md)。

`v0.1.0-preview.1` 是技术预览版。源码、构建和发布证据都公开；没有 Developer ID 之前，不把未公证下载包包装成正式稳定版。

MIT License。

</details>


</details>
