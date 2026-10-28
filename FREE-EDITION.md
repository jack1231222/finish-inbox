# FinishInbox Free: download and installation

## [Download the free notarized app for macOS](https://github.com/jack1231222/finish-inbox/releases/download/v0.2.0-free-preview.1/FinishInbox-Free-0.2.0-notarized-macos.zip)

**Download this ZIP: `FinishInbox-Free-0.2.0-notarized-macos.zip`**

[SHA-256 checksum](https://github.com/jack1231222/finish-inbox/releases/download/v0.2.0-free-preview.1/FinishInbox-Free-0.2.0-notarized-macos.zip.sha256) · [Release page](https://github.com/jack1231222/finish-inbox/releases/tag/v0.2.0-free-preview.1) · [Chinese guide](README.zh-CN.md)

| Download | Status | What to choose |
| --- | --- | --- |
| `FinishInbox-Free-0.2.0-notarized-macos.zip` | Recommended · Apple notarized | Download and unzip this app |
| `FinishInbox-Free-0.2.0-notarized-macos.zip.sha256` | Checksum for the notarized app | Use it to verify the ZIP above |
| Older filenames containing `preview.1-macos.zip` | Historical · Not notarized | Retained for reference; not recommended |
| `FinishInbox-v0.1.0-preview.1.zip` | Historical open-source preview · Not notarized | Not the current Free edition |
| GitHub-generated Source code archives | Historical open-source code | Not an app download or the current Free source |

## Installation

1. Unzip the recommended download and drag **FinishInbox Free.app** into **Applications**.
2. Open the app and choose whether to enable local Codex monitoring.
3. View completion counts and pending replies in the menu bar. A completion item clears the count for that project when clicked. The pending-replies list can open the corresponding Codex conversation.
4. Use **F✓** to start or pause monitoring, or quit. To launch at login, add the app to macOS Login Items yourself.

First launch does not replay historical completion notifications. Only recognized structured events from local Codex sessions are supported. Cloud sessions, remote hosts, other agents, and every Codex version are not guaranteed to provide compatible events.

## System requirements and release status

- Includes Apple Silicon and Intel binaries targeting macOS 13 or later.
- Automated checks and real download/launch verification were performed on macOS 27 / Apple Silicon. Intel and older macOS have not been tested on hardware.
- Signed with Developer ID, accepted by Apple's notary service, and supplied with a stapled notarization ticket. macOS may show its normal internet-download confirmation. The app does not remove quarantine attributes or change system security settings.
- Native UI verification covered first-run enablement, repeated list opening and closing, clearing completion counts, pausing and resuming monitoring, reply updates, and quitting. This remains a preview release.

## Privacy and local data

- The app reads structured Codex completion and waiting-for-reply events, plus names and project metadata for pending conversations, on your Mac.
- No data uploads or cloud analytics. Chat message bodies are not retained and account credentials are not accessed. Reminder titles are visible in the menu bar; take care when sharing your screen.
- Free-edition state is stored in `~/Library/Application Support/FinishInbox Free/`, separately from any existing reminder tool.
- Only the compiled app and documentation are included. The publisher's name appears only in the signing certificate. No other personal information, project mappings, chat history, databases, runtime logs, private keys, or current implementation source is bundled.

## Optional: manual events and project labels

Local scripts can send a completion event using the app's executable:

```sh
"/Applications/FinishInbox Free.app/Contents/MacOS/FinishInbox" --event --project "Demo" --event-id "unique-completion-id"
```

For project labels, create `projects.json` in the data folder above, using a JSON mapping from local absolute project paths to display names. Keep your own mapping file private.

## Quit and uninstall

Quitting from **F✓** stops the watcher started by this app. Removing the app does not delete your local reminder state. You decide whether to remove that data separately.

## Source code

The GitHub repository retains a historical open-source version under its original license. The current Free edition is distributed as compiled software only. You do not need to download or build the source to use the free app.
