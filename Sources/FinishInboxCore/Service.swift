import Foundation

public final class FinishInboxService: @unchecked Sendable {
    public static let processedEventRetention: TimeInterval = 7 * 24 * 60 * 60
    public static let processedEventLimit = 10_000

    public let store: FinishInboxStore
    private let now: @Sendable () -> Date

    public init(store: FinishInboxStore = FinishInboxStore(), now: @escaping @Sendable () -> Date = Date.init) {
        self.store = store
        self.now = now
    }

    public static func resolvedDirectory(_ path: String) -> String {
        URL(fileURLWithPath: path, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL.path
    }

    @discardableResult
    public func map(directory: String, to rawLabel: String) throws -> String {
        let path = Self.resolvedDirectory(directory)
        let label = try InputValidation.normalizeLabel(rawLabel)
        try store.withConfigLock {
            var config = try store.loadConfig()
            config.mappings[path] = label
            try store.saveConfig(config)
        }
        return label
    }

    public func unmap(directory: String) throws -> Bool {
        let path = Self.resolvedDirectory(directory)
        return try store.withConfigLock {
            var config = try store.loadConfig()
            let removed = config.mappings.removeValue(forKey: path) != nil
            if removed { try store.saveConfig(config) }
            return removed
        }
    }

    public func resolveProject(directory: String, explicitLabel: String? = nil) throws -> String {
        if let explicitLabel {
            // A corrupt private config is still a notify precondition failure, even when
            // this invocation supplies an explicit label. Never silently overwrite it.
            _ = try store.loadConfig()
            return try InputValidation.normalizeLabel(explicitLabel)
        }
        let path = Self.resolvedDirectory(directory)
        let config = try store.loadConfig()
        guard let label = config.mappings
            .filter({ mappingPath, _ in
                path == mappingPath || path.hasPrefix(mappingPath + "/")
            })
            .max(by: { $0.key.count < $1.key.count })?.value else {
            throw FinishInboxError.mappingMissing
        }
        return label
    }

    @discardableResult
    public func notify(directory: String, explicitLabel: String? = nil, eventID: String? = nil) throws -> CompletionEvent {
        let project = try resolveProject(directory: directory, explicitLabel: explicitLabel)
        let id = try InputValidation.validateEventID(eventID ?? UUID().uuidString)
        let event = CompletionEvent(id: id, project: project, createdAt: now())
        try store.queue(event)
        return event
    }

    @discardableResult
    public func reconcile() throws -> ReconcileResult {
        try store.withOperationLock {
            var state = try store.loadState()
            try store.removeTemporaryEvents()
            var accepted = 0
            var duplicates = 0
            var quarantined = 0

            for url in try store.eventURLs() {
                let event: CompletionEvent
                do {
                    event = try store.decodeEvent(at: url)
                } catch {
                    try store.quarantineEvent(at: url)
                    quarantined += 1
                    continue
                }

                if state.processedEvents[event.id] != nil {
                    try store.removeEvent(at: url)
                    duplicates += 1
                    continue
                }

                var next = state
                next.counts[event.project, default: 0] += 1
                next.processedEvents[event.id] = now()
                Self.prune(&next, now: now())
                try store.saveState(next)
                try store.removeEvent(at: url)
                state = next
                accepted += 1
            }

            let beforePruning = state
            Self.prune(&state, now: now())
            if state != beforePruning { try store.saveState(state) }
            return ReconcileResult(
                accepted: accepted,
                duplicates: duplicates,
                quarantined: quarantined,
                state: state
            )
        }
    }

    @discardableResult
    public func clear(project rawProject: String) throws -> ReminderState {
        let project = try InputValidation.normalizeLabel(rawProject)
        return try store.withOperationLock {
            var state = try reconcileWhileLocked()
            state.counts.removeValue(forKey: project)

            // These are normally gone after reconciliation. Keeping this pass makes the
            // clear postcondition explicit if a future event source adds ordered files.
            for url in try store.eventURLs() {
                guard let event = try? store.decodeEvent(at: url), event.project == project else { continue }
                try store.removeEvent(at: url)
            }
            Self.prune(&state, now: now())
            try store.saveState(state)
            return state
        }
    }

    public func status() throws -> ReminderState {
        try store.loadState()
    }

    public static func prune(_ state: inout ReminderState, now: Date) {
        let cutoff = now.addingTimeInterval(-processedEventRetention)
        state.processedEvents = state.processedEvents.filter { $0.value >= cutoff }
        if state.processedEvents.count > processedEventLimit {
            let newest = state.processedEvents
                .sorted { lhs, rhs in
                    if lhs.value == rhs.value { return lhs.key < rhs.key }
                    return lhs.value > rhs.value
                }
                .prefix(processedEventLimit)
            state.processedEvents = Dictionary(uniqueKeysWithValues: newest.map { ($0.key, $0.value) })
        }
    }

    private func reconcileWhileLocked() throws -> ReminderState {
        var state = try store.loadState()
        try store.removeTemporaryEvents()
        for url in try store.eventURLs() {
            let event: CompletionEvent
            do {
                event = try store.decodeEvent(at: url)
            } catch {
                try store.quarantineEvent(at: url)
                continue
            }
            if state.processedEvents[event.id] != nil {
                try store.removeEvent(at: url)
                continue
            }
            var next = state
            next.counts[event.project, default: 0] += 1
            next.processedEvents[event.id] = now()
            Self.prune(&next, now: now())
            try store.saveState(next)
            try store.removeEvent(at: url)
            state = next
        }
        return state
    }
}
