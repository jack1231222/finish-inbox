import Darwin
import Foundation
import Testing
@testable import FinishInboxCore

@Suite("FinishInbox Core")
struct FinishInboxCoreTests {
    private func fixture(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) throws -> (URL, FinishInboxStore, FinishInboxService) {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("FinishInboxTests-\(UUID().uuidString)")
        let store = FinishInboxStore(paths: StoragePaths(root: base.appendingPathComponent("state")))
        let service = FinishInboxService(store: store, now: { now })
        return (base, store, service)
    }

    private func cleanup(_ base: URL) {
        try? FileManager.default.removeItem(at: base)
    }

    private func writePrivate(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        #expect(Darwin.chmod(url.path, S_IRUSR | S_IWUSR) == 0)
    }

    @Test("event IDs are strict and never rewritten")
    func eventIDValidation() throws {
        #expect(try InputValidation.validateEventID("a_B-09") == "a_B-09")
        #expect(throws: FinishInboxError.invalidEventID) { try InputValidation.validateEventID("a/b") }
        #expect(throws: FinishInboxError.invalidEventID) { try InputValidation.validateEventID("") }
        #expect(throws: FinishInboxError.invalidEventID) { try InputValidation.validateEventID(String(repeating: "a", count: 129)) }
    }

    @Test("labels normalize whitespace and reject control and bidi text")
    func labelValidation() throws {
        #expect(try InputValidation.normalizeLabel("  Project A  ") == "Project A")
        #expect(throws: FinishInboxError.self) { try InputValidation.normalizeLabel("bad\nlabel") }
        #expect(throws: FinishInboxError.self) { try InputValidation.normalizeLabel("safe\u{202E}txt") }
    }

    @Test("menu labels select Chinese or English automatically")
    func labelFormatting() {
        #expect(DisplayFormatting.menuBarLabel(project: "My App", count: 2) == "My App · 2 done ✓")
        #expect(DisplayFormatting.menuBarLabel(project: "杂", count: 4) == "杂 · 3+ 完成 ✓")
        #expect(DisplayFormatting.menuBarLabel(project: "abcdefghijklmn", count: 1) == "abcdefghijkl… · 1 done ✓")
    }

    @Test("menu bar projection sorts active projects and isolates overflow")
    func menuBarProjectGroups() {
        let state = ReminderState(counts: [
            "G": 1,
            "A": 1,
            "F": 1,
            "zero": 0,
            "C": 2,
            "B": 1,
            "E": 1,
            "D": 1,
        ])

        let groups = MenuBarProjectGroups(state: state)

        #expect(groups.visible == ["A", "B", "C", "D", "E", "F"])
        #expect(groups.overflow == ["G"])
    }

    @Test("menu bar projection honors a bounded visible limit")
    func menuBarProjectGroupsWithCustomLimit() {
        let state = ReminderState(counts: ["A": 1, "B": 1, "C": 1])

        #expect(MenuBarProjectGroups(state: state, visibleLimit: 2).visible == ["A", "B"])
        #expect(MenuBarProjectGroups(state: state, visibleLimit: 2).overflow == ["C"])
        #expect(MenuBarProjectGroups(state: state, visibleLimit: -1).visible.isEmpty)
    }

    @Test("implicit project resolution fails closed")
    func missingMapping() throws {
        let (base, _, service) = try fixture()
        defer { cleanup(base) }
        #expect(throws: FinishInboxError.mappingMissing) {
            try service.resolveProject(directory: base.path)
        }
    }

    @Test("longest prefix mapping and symlinks resolve to the private label")
    func longestPrefixAndSymlink() throws {
        let (base, _, service) = try fixture()
        defer { cleanup(base) }
        let real = base.appendingPathComponent("real")
        let nested = real.appendingPathComponent("nested")
        let child = nested.appendingPathComponent("child")
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try service.map(directory: real.path, to: "General")
        try service.map(directory: nested.path, to: "Specific")
        #expect(try service.resolveProject(directory: child.path) == "Specific")

        let link = base.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        #expect(try service.resolveProject(directory: link.appendingPathComponent("nested/child").path) == "Specific")
    }

    @Test("malformed config is not treated as empty")
    func malformedConfig() throws {
        let (base, store, _) = try fixture()
        defer { cleanup(base) }
        try store.prepare()
        try writePrivate(Data("{".utf8), to: store.paths.config)
        #expect(throws: FinishInboxError.malformedConfig) { try store.loadConfig() }
        #expect(try Data(contentsOf: store.paths.config) == Data("{".utf8))
    }

    @Test("explicit notify also refuses to ignore a malformed config")
    func explicitNotifyChecksConfig() throws {
        let (base, store, service) = try fixture()
        defer { cleanup(base) }
        try store.prepare()
        try writePrivate(Data("{".utf8), to: store.paths.config)
        #expect(throws: FinishInboxError.malformedConfig) {
            try service.notify(directory: base.path, explicitLabel: "Explicit", eventID: "explicit-id")
        }
        #expect(try store.eventURLs().isEmpty)
    }

    @Test("private roots and files use 0700 and 0600")
    func privatePermissions() throws {
        let (base, store, service) = try fixture()
        defer { cleanup(base) }
        try service.map(directory: base.path, to: "Private")
        _ = try service.notify(directory: base.path, eventID: "private-id")
        #expect(store.fileMode(at: store.paths.root) == 0o700)
        #expect(store.fileMode(at: store.paths.events) == 0o700)
        #expect(store.fileMode(at: store.paths.config) == 0o600)
        let eventURL = try #require(try store.eventURLs().first)
        #expect(store.fileMode(at: eventURL) == 0o600)
    }

    @Test("queued event contains no directory path")
    func queuedEventPrivacy() throws {
        let (base, store, service) = try fixture()
        defer { cleanup(base) }
        try service.map(directory: base.path, to: "Safe Label")
        _ = try service.notify(directory: base.path, eventID: "privacy-id")
        let url = try #require(try store.eventURLs().first)
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(!text.contains(base.path))
        #expect(text.contains("Safe Label"))
    }

    @Test("malformed events are quarantined while valid events reconcile")
    func quarantineIsolation() throws {
        let (base, store, service) = try fixture()
        defer { cleanup(base) }
        try store.prepare()
        try writePrivate(Data("not json".utf8), to: store.paths.events.appendingPathComponent("bad.json"))
        try store.queue(CompletionEvent(id: "valid-id", project: "Project"))
        let result = try service.reconcile()
        #expect(result.accepted == 1)
        #expect(result.quarantined == 1)
        #expect(result.state.counts == ["Project": 1])
        #expect(try store.eventURLs().isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.paths.quarantine.path).count == 1)
    }

    @Test("truncated state is preserved and blocks reconciliation")
    func corruptStatePreserved() throws {
        let (base, store, service) = try fixture()
        defer { cleanup(base) }
        try store.prepare()
        try store.queue(CompletionEvent(id: "blocked-id", project: "Project"))
        let original = Data("{\"schemaVersion\":".utf8)
        try writePrivate(original, to: store.paths.state)
        do {
            _ = try service.reconcile()
            Issue.record("reconciliation unexpectedly accepted a truncated state")
        } catch let error as FinishInboxError {
            #expect(error == .malformedState)
        }
        #expect(try Data(contentsOf: store.paths.state) == original)
        #expect(try store.eventURLs().map(\.lastPathComponent) == ["blocked-id.json"])
    }

    @Test("duplicates are idempotent across restart-style reconciliation")
    func duplicateIDs() throws {
        let (base, store, service) = try fixture()
        defer { cleanup(base) }
        try store.queue(CompletionEvent(id: "same-id", project: "Project"))
        #expect(try service.reconcile().state.counts["Project"] == 1)
        try store.queue(CompletionEvent(id: "same-id", project: "Project"))
        #expect(try service.reconcile().state.counts["Project"] == 1)
        #expect(try store.eventURLs().isEmpty)
    }

    @Test("clear isolates projects and events ordered afterward survive")
    func clearOrderingAndIsolation() throws {
        let (base, store, service) = try fixture()
        defer { cleanup(base) }
        try store.queue(CompletionEvent(id: "a-before", project: "A"))
        try store.queue(CompletionEvent(id: "b-before", project: "B"))
        let cleared = try service.clear(project: "A")
        #expect(cleared.counts["A"] == nil)
        #expect(cleared.counts["B"] == 1)
        try store.queue(CompletionEvent(id: "a-after", project: "A"))
        let final = try service.reconcile().state
        #expect(final.counts["A"] == 1)
        #expect(final.counts["B"] == 1)
    }

    @Test("processed IDs are retained for seven days and capped at 10000 newest")
    func boundedPruning() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        var events: [String: Date] = [
            "expired": now.addingTimeInterval(-FinishInboxService.processedEventRetention - 1),
            "boundary": now.addingTimeInterval(-FinishInboxService.processedEventRetention),
        ]
        for index in 0..<10_005 {
            events["id-\(index)"] = now.addingTimeInterval(TimeInterval(index))
        }
        var state = ReminderState(processedEvents: events)
        FinishInboxService.prune(&state, now: now)
        #expect(state.processedEvents.count == 10_000)
        #expect(state.processedEvents["expired"] == nil)
        #expect(state.processedEvents["id-10004"] != nil)
        #expect(state.processedEvents["id-0"] == nil)
    }

    @Test("only one manager lock can be held in this process")
    func singleManager() throws {
        let (base, store, _) = try fixture()
        defer { cleanup(base) }
        let first = try store.acquireManagerLock()
        #expect(throws: FinishInboxError.cannotAcquireLock) { try store.acquireManagerLock() }
        first.unlock()
        let third = try store.acquireManagerLock()
        third.unlock()
    }

    @Test("concurrent notifications do not lose events")
    func concurrentNotify() throws {
        let (base, store, _) = try fixture()
        defer { cleanup(base) }
        let service = FinishInboxService(store: store)
        try service.map(directory: base.path, to: "Concurrent")
        let errorLock = NSLock()
        nonisolated(unsafe) var errors: [Error] = []
        DispatchQueue.concurrentPerform(iterations: 50) { index in
            do {
                _ = try service.notify(directory: base.path, eventID: "event-\(index)")
            } catch {
                errorLock.lock()
                errors.append(error)
                errorLock.unlock()
            }
        }
        #expect(errors.isEmpty)
        let state = try service.reconcile().state
        #expect(state.counts["Concurrent"] == 50)
        #expect(state.processedEvents.count == 50)
    }

    @Test("unknown schemas and unsafe permissions are rejected")
    func schemaAndPermissionRejection() throws {
        let (base, store, _) = try fixture()
        defer { cleanup(base) }
        try store.prepare()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let unsupported = ReminderState(schemaVersion: 2)
        try writePrivate(try encoder.encode(unsupported), to: store.paths.state)
        #expect(throws: FinishInboxError.unsupportedSchema("state", 2)) { try store.loadState() }
        #expect(Darwin.chmod(store.paths.state.path, S_IRUSR | S_IWUSR | S_IROTH) == 0)
        #expect(throws: FinishInboxError.self) { try store.loadState() }
    }

    @Test("valid JSON state rejects unsafe labels and overflowing counts")
    func invalidStateContentRejection() throws {
        let (base, store, _) = try fixture()
        defer { cleanup(base) }
        try store.prepare()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        try writePrivate(
            try encoder.encode(ReminderState(counts: ["bad\nlabel": 1])),
            to: store.paths.state
        )
        #expect(throws: FinishInboxError.self) { try store.loadState() }

        try writePrivate(
            try encoder.encode(ReminderState(counts: ["Project": Int.max])),
            to: store.paths.state
        )
        #expect(throws: FinishInboxError.self) { try store.loadState() }
    }

    @Test("status is read-only when storage has never been created")
    func statusReadOnly() throws {
        let (base, store, service) = try fixture()
        defer { cleanup(base) }
        #expect(try service.status() == ReminderState())
        #expect(!FileManager.default.fileExists(atPath: store.paths.root.path))
    }
}
