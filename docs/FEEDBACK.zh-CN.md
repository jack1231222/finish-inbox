# 反馈与升级流程

FinishInbox 用 Discussions 收集早期想法和使用问题；只有范围明确、能够复现和验收的工作，才进入 Issues。

[English](FEEDBACK.md)

## 该发到哪里

| 反馈类型 | 提交位置 | 建议附上 |
| --- | --- | --- |
| 功能想法、使用流程、接入需求 | [统一反馈讨论](https://github.com/jack1231222/finish-inbox/discussions/1) | 目前漏掉完成提醒的场景，以及哪个工具应该发事件 |
| 安装或使用问题 | [Q&A](https://github.com/jack1231222/finish-inbox/discussions/categories/q-a) | macOS、FinishInbox 版本，执行的命令和脱敏后的输出 |
| 能够复现的缺陷 | [Bug 报告](https://github.com/jack1231222/finish-inbox/issues/new?template=bug_report.yml) | 最小复现步骤、预期结果、实际结果和隐私影响 |
| 安全漏洞 | [私密安全报告](https://github.com/jack1231222/finish-inbox/security/advisories/new) | 影响范围和安全的复现方式，不要先公开披露 |

提交前先看看是否已有相同讨论。已有的话直接评论或点赞，需求强度会更清楚，也不会把证据拆散。

## 反馈怎么进入新版本

1. Discussion 先收集真实场景、替代方案和需求强度。
2. 行为和隐私边界明确后，能够复现的工作转成带验收条件的 Issue。
3. 代码改动必须有测试，或者等价的真实行为证据。
4. CHANGELOG 和 Release Notes 记录已经发布的内容，以及仍然存在的限制。
5. 回到原 Discussion 或 Issue 更新结果，方便反馈人复验。

反馈会影响优先级，但不等于自动承诺。正确性、本地隐私和维护成本仍然是发布门槛。

## 发出前先脱敏

不要公开提示词、模型回复、API Key、完整日志、私人路径、`config.json`、`state.json` 或事件文件。分享输出前，把本地项目名和路径替换成简短占位词。
