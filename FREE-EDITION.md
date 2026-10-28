# FinishInbox Free：下载与使用

## [⬇ 下载免费公证版（macOS）](https://github.com/jack1231222/finish-inbox/releases/download/v0.2.0-free-preview.1/FinishInbox-Free-0.2.0-notarized-macos.zip)

**只需下载这个 ZIP：`FinishInbox-Free-0.2.0-notarized-macos.zip`。**

[SHA-256 校验文件](https://github.com/jack1231222/finish-inbox/releases/download/v0.2.0-free-preview.1/FinishInbox-Free-0.2.0-notarized-macos.zip.sha256) · [发行页](https://github.com/jack1231222/finish-inbox/releases/tag/v0.2.0-free-preview.1)

| 下载项 | 状态 | 怎么选 |
| --- | --- | --- |
| `FinishInbox-Free-0.2.0-notarized-macos.zip` | 当前推荐 · Apple 公证版 | 下载并解压这个文件 |
| `FinishInbox-Free-0.2.0-notarized-macos.zip.sha256` | 公证版校验文件 | 用于核对上方 ZIP |
| 文件名含 `preview.1-macos.zip` 的旧包 | 历史 · 未公证 | 保留查阅，不推荐下载 |
| `FinishInbox-v0.1.0-preview.1.zip` | 历史开源版 · 未公证 | 保留查阅，不是当前免费版 |
| GitHub 自动生成的 Source code | 历史开源代码 | 不是当前应用包，也不包含当前免费版源码 |

## 使用

1. 将 `FinishInbox Free.app` 拖到“应用程序”文件夹后打开。
2. 首次运行选择是否启用本地 Codex 监听。
3. 任务完成后在菜单栏查看计数；点击完成提醒清除该项目的计数。待回复提醒可查看对话列表并打开相应 Codex 对话。
4. 从菜单栏 `F✓` 可启动、暂停监听或退出。登录时自动打开可由用户在 macOS“登录项”中自行设置。

首次启用不会补发历史完成提醒；只处理本地 Codex 会话中可识别的结构化事件。不能保证云端、远程主机、其他代理或所有 Codex 版本都提供这些事件。

## 系统与发行状态

- 包含 Apple Silicon 和 Intel 两种架构；部署目标为 macOS 13 及以上。
- 本次自动化功能检查在 Apple Silicon / macOS 27 上通过；Intel 和旧系统未作实机验证。
- 当前免费预览版使用 Developer ID 签名，已通过 Apple 公证并附有公证票据。首次打开仍可能显示 macOS 的普通互联网下载确认；应用不移除隔离标记，也不修改系统安全设置。
- 已在本机通过首次启用、列表反复开关、完成计数清除、暂停与恢复、回复后更新及退出的原生界面验证；当前仍以预览版发行。

## 隐私与数据

- 应用在本机读取 Codex 的结构化完成/待回复事件，以及待回复对话的名称和项目元数据。
- 不上传数据，无云端统计；不保存聊天正文或读取账号凭证。提醒名称在本机菜单栏显示，请留意屏幕共享。
- 免费版数据保存在当前用户的 `~/Library/Application Support/FinishInbox Free/`，与既有本机提醒工具的数据分开。
- 此下载只包含编译后的应用和说明。发布者姓名仅存在于签名证书中；不包含其他个人资料、项目映射、聊天、数据库、运行日志或当前实现源码。

## 手动通知与项目别名（可选）

本地脚本可调用应用内的可执行文件发送完成事件：

```sh
"/Applications/FinishInbox Free.app/Contents/MacOS/FinishInbox" --event --project "Demo" --event-id "unique-completion-id"
```

项目别名可写入上述数据目录的 `projects.json`，使用本机项目绝对路径到显示名称的 JSON 映射；不要公开自己的映射文件。

## 退出与移除

从 `F✓` 退出会停止本次应用启动的监听器。移除应用不会删除本机提醒记录；是否另行清理数据目录由用户决定。

## 源码说明

GitHub 仓库保留的旧版源码属于历史开源版本。此次免费版只发布编译产物，不公开当前实现源码；免费使用不要求下载源码。
