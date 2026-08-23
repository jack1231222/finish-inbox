import AppKit
import FinishInboxCore
import Foundation

@MainActor
final class CompletionManager: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let service: FinishInboxService
    private let headless: Bool
    private let runOnce: Bool
    private var managerLock: FileLock?
    private var timer: Timer?
    private var state = ReminderState()
    private var projectItems: [String: NSStatusItem] = [:]
    private var overflowItem: NSStatusItem?

    init(service: FinishInboxService, headless: Bool, runOnce: Bool) {
        self.service = service
        self.headless = headless
        self.runOnce = runOnce
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            managerLock = try service.store.acquireManagerLock()
            try refresh()
        } catch FinishInboxError.cannotAcquireLock {
            NSApp.terminate(nil)
            return
        } catch {
            FileHandle.standardError.write(Data("finish-inbox manager: \(error.localizedDescription)\n".utf8))
            NSApp.terminate(nil)
            return
        }

        if runOnce {
            NSApp.terminate(nil)
            return
        }
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(refreshTimer), userInfo: nil, repeats: true)
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        managerLock?.unlock()
        managerLock = nil
    }

    private func refresh() throws {
        state = try service.reconcile().state
        reconcileStatusItems()
    }

    @objc private func refreshTimer() {
        try? refresh()
    }

    private func reconcileStatusItems() {
        guard !headless else { return }
        let active = state.counts.filter { $0.value > 0 }
        let groups = MenuBarProjectGroups(state: state)
        let visibleProjects = Set(groups.visible)

        for project in Array(projectItems.keys) where !visibleProjects.contains(project) {
            if let item = projectItems.removeValue(forKey: project) {
                NSStatusBar.system.removeStatusItem(item)
            }
        }

        for project in groups.visible {
            let item = projectItems[project] ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            guard let button = item.button, let count = active[project] else { continue }
            button.title = DisplayFormatting.menuBarLabel(project: project, count: count)
            button.image = nil
            button.font = .systemFont(ofSize: 13, weight: .medium)
            button.toolTip = "\(project): \(count) unread completions. Click to clear."
            button.identifier = NSUserInterfaceItemIdentifier(project)
            button.target = self
            button.action = #selector(clearVisibleProject(_:))
            projectItems[project] = item
        }

        let overflowProjects = groups.overflow
        if overflowProjects.isEmpty {
            if let overflowItem {
                NSStatusBar.system.removeStatusItem(overflowItem)
                self.overflowItem = nil
            }
            return
        }

        let item = overflowItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "+\(overflowProjects.count) ✓"
        item.button?.toolTip = "More FinishInbox projects"
        let menu = NSMenu(title: "FinishInbox")
        menu.delegate = self
        for project in overflowProjects {
            let menuItem = NSMenuItem(
                title: DisplayFormatting.menuBarLabel(project: project, count: active[project] ?? 0),
                action: #selector(clearOverflowProject(_:)),
                keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.representedObject = project
            menu.addItem(menuItem)
        }
        item.menu = menu
        overflowItem = item
    }

    @objc private func clearVisibleProject(_ sender: Any?) {
        guard let button = sender as? NSStatusBarButton,
              let project = button.identifier?.rawValue else { return }
        clear(project)
    }

    @objc private func clearOverflowProject(_ sender: Any?) {
        guard let item = sender as? NSMenuItem, let project = item.representedObject as? String else { return }
        clear(project)
    }

    private func clear(_ project: String) {
        do {
            state = try service.clear(project: project)
            reconcileStatusItems()
        } catch {
            NSSound.beep()
        }
    }
}

@MainActor
func runManager(service: FinishInboxService, headless: Bool, runOnce: Bool) -> Never {
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    let manager = CompletionManager(service: service, headless: headless, runOnce: runOnce)
    application.delegate = manager
    application.run()
    exit(EXIT_SUCCESS)
}
