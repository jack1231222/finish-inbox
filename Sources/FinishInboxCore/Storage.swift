import Darwin
import Foundation

public struct StoragePaths: Sendable {
    public let root: URL
    public let events: URL
    public let quarantine: URL
    public let state: URL
    public let config: URL
    public let operationLock: URL
    public let configLock: URL
    public let managerLock: URL

    public init(root: URL) {
        self.root = root
        events = root.appendingPathComponent("events", isDirectory: true)
        quarantine = root.appendingPathComponent("quarantine", isDirectory: true)
        state = root.appendingPathComponent("state.json")
        config = root.appendingPathComponent("config.json")
        operationLock = root.appendingPathComponent("operation.lock")
        configLock = root.appendingPathComponent("config.lock")
        managerLock = root.appendingPathComponent("manager.lock")
    }

    public static func fromEnvironment() -> StoragePaths {
        var environment: [String: String] = [:]
        if let rawValue = "FINISH_INBOX_HOME".withCString({ Darwin.getenv($0) }) {
            environment["FINISH_INBOX_HOME"] = String(cString: rawValue)
        }
        return fromEnvironment(environment)
    }

    public static func fromEnvironment(_ environment: [String: String]) -> StoragePaths {
        let home: URL
        if let override = environment["FINISH_INBOX_HOME"], !override.isEmpty {
            home = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            home = FileManager.default.homeDirectoryForCurrentUser
        }
        return StoragePaths(
            root: home
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent("FinishInbox", isDirectory: true)
        )
    }
}

public final class FileLock: @unchecked Sendable {
    private final class Registry: @unchecked Sendable {
        static let shared = Registry()
        private let registryLock = NSLock()
        private var locks: [String: NSLock] = [:]

        func lock(for path: String) -> NSLock {
            registryLock.lock()
            defer { registryLock.unlock() }
            if let existing = locks[path] { return existing }
            let created = NSLock()
            locks[path] = created
            return created
        }
    }

    private var descriptor: Int32 = -1
    private let processLock: NSLock
    private var holdsProcessLock = false

    public init(url: URL, blocking: Bool) throws {
        processLock = Registry.shared.lock(for: url.path)
        let acquiredInProcess = blocking ? ({ processLock.lock(); return true }()) : processLock.try()
        guard acquiredInProcess else {
            descriptor = -1
            throw FinishInboxError.cannotAcquireLock
        }
        holdsProcessLock = true
        descriptor = Darwin.open(url.path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            processLock.unlock()
            holdsProcessLock = false
            throw FinishInboxError.cannotOpenLock
        }
        _ = Darwin.fchmod(descriptor, S_IRUSR | S_IWUSR)
        guard Self.set(descriptor, type: Int16(F_WRLCK), blocking: blocking) else {
            Darwin.close(descriptor)
            descriptor = -1
            processLock.unlock()
            holdsProcessLock = false
            throw FinishInboxError.cannotAcquireLock
        }
    }

    deinit { unlock() }

    public func unlock() {
        guard descriptor >= 0 else { return }
        _ = Self.set(descriptor, type: Int16(F_UNLCK), blocking: false)
        Darwin.close(descriptor)
        descriptor = -1
        if holdsProcessLock {
            processLock.unlock()
            holdsProcessLock = false
        }
    }

    private static func set(_ descriptor: Int32, type: Int16, blocking: Bool) -> Bool {
        var lock = Darwin.flock()
        lock.l_start = 0
        lock.l_len = 0
        lock.l_pid = 0
        lock.l_type = type
        lock.l_whence = Int16(SEEK_SET)
        return Darwin.fcntl(descriptor, blocking ? F_SETLKW : F_SETLK, &lock) != -1
    }
}

public final class FinishInboxStore: @unchecked Sendable {
    public let paths: StoragePaths
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(paths: StoragePaths = .fromEnvironment(), fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func prepare() throws {
        try makePrivateDirectory(paths.root)
        try makePrivateDirectory(paths.events)
        try makePrivateDirectory(paths.quarantine)
    }

    public func withOperationLock<T>(_ body: () throws -> T) throws -> T {
        try prepare()
        let lock = try FileLock(url: paths.operationLock, blocking: true)
        defer { lock.unlock() }
        return try body()
    }

    public func acquireManagerLock() throws -> FileLock {
        try prepare()
        return try FileLock(url: paths.managerLock, blocking: false)
    }

    public func withConfigLock<T>(_ body: () throws -> T) throws -> T {
        try prepare()
        let lock = try FileLock(url: paths.configLock, blocking: true)
        defer { lock.unlock() }
        return try body()
    }

    public func loadState() throws -> ReminderState {
        guard fileManager.fileExists(atPath: paths.state.path) else { return ReminderState() }
        guard fileMode(at: paths.state) == 0o600 else {
            throw FinishInboxError.storage("state file permissions must be 0600")
        }
        let state: ReminderState
        do {
            state = try decoder.decode(ReminderState.self, from: Data(contentsOf: paths.state))
        } catch {
            throw FinishInboxError.malformedState
        }
        guard state.schemaVersion == finishInboxSchemaVersion else {
            throw FinishInboxError.unsupportedSchema("state", state.schemaVersion)
        }
        guard state.counts.allSatisfy({
            $0.value > 0 && $0.value < Int.max
                && (try? InputValidation.normalizeLabel($0.key)) == $0.key
        }) else {
            throw FinishInboxError.invalidState("counts must contain normalized labels and non-overflowing positive values")
        }
        guard state.processedEvents.keys.allSatisfy({ (try? InputValidation.validateEventID($0)) != nil }) else {
            throw FinishInboxError.invalidState("processed event ID is invalid")
        }
        guard state.processedEvents.count <= 10_000 else {
            throw FinishInboxError.invalidState("processed event history exceeds 10000 entries")
        }
        return state
    }

    public func loadConfig() throws -> ProjectConfig {
        guard fileManager.fileExists(atPath: paths.config.path) else { return ProjectConfig() }
        guard fileMode(at: paths.config) == 0o600 else {
            throw FinishInboxError.storage("config file permissions must be 0600")
        }
        let config: ProjectConfig
        do {
            config = try decoder.decode(ProjectConfig.self, from: Data(contentsOf: paths.config))
        } catch {
            throw FinishInboxError.malformedConfig
        }
        guard config.schemaVersion == finishInboxSchemaVersion else {
            throw FinishInboxError.unsupportedSchema("config", config.schemaVersion)
        }
        for (path, label) in config.mappings {
            guard path.hasPrefix("/") else { throw FinishInboxError.malformedConfig }
            guard (try? InputValidation.normalizeLabel(label)) == label else {
                throw FinishInboxError.malformedConfig
            }
        }
        return config
    }

    public func saveState(_ state: ReminderState) throws {
        guard state.schemaVersion == finishInboxSchemaVersion,
              state.counts.allSatisfy({
                  $0.value > 0 && $0.value < Int.max
                      && (try? InputValidation.normalizeLabel($0.key)) == $0.key
              }),
              state.processedEvents.count <= 10_000,
              state.processedEvents.keys.allSatisfy({ (try? InputValidation.validateEventID($0)) != nil }) else {
            throw FinishInboxError.invalidState("state invariants failed")
        }
        try atomicWrite(try encoder.encode(state), to: paths.state)
    }

    public func saveConfig(_ config: ProjectConfig) throws {
        guard config.schemaVersion == finishInboxSchemaVersion else {
            throw FinishInboxError.unsupportedSchema("config", config.schemaVersion)
        }
        guard config.mappings.allSatisfy({ path, label in
            path.hasPrefix("/") && (try? InputValidation.normalizeLabel(label)) == label
        }) else {
            throw FinishInboxError.malformedConfig
        }
        try atomicWrite(try encoder.encode(config), to: paths.config)
    }

    public func eventURLs() throws -> [URL] {
        try prepare()
        return try fileManager.contentsOfDirectory(
            at: paths.events,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public func decodeEvent(at url: URL) throws -> CompletionEvent {
        guard fileMode(at: url) == 0o600 else {
            throw FinishInboxError.storage("event file permissions must be 0600")
        }
        let event = try decoder.decode(CompletionEvent.self, from: Data(contentsOf: url))
        guard event.schemaVersion == finishInboxSchemaVersion else {
            throw FinishInboxError.unsupportedSchema("event", event.schemaVersion)
        }
        _ = try InputValidation.validateEventID(event.id)
        guard try InputValidation.normalizeLabel(event.project) == event.project else {
            throw FinishInboxError.invalidProjectLabel("event label is not normalized")
        }
        return event
    }

    public func queue(_ event: CompletionEvent) throws {
        _ = try InputValidation.validateEventID(event.id)
        guard try InputValidation.normalizeLabel(event.project) == event.project else {
            throw FinishInboxError.invalidProjectLabel("label is not normalized")
        }
        try withOperationLock {
            let state = try loadState()
            let finalURL = paths.events.appendingPathComponent("\(event.id).json")
            if state.processedEvents[event.id] != nil || fileManager.fileExists(atPath: finalURL.path) { return }
            try atomicWrite(try encoder.encode(event), to: finalURL)
        }
    }

    public func quarantineEvent(at url: URL) throws {
        let destination = paths.quarantine.appendingPathComponent(
            "\(url.deletingPathExtension().lastPathComponent)-\(UUID().uuidString).json"
        )
        guard Darwin.rename(url.path, destination.path) == 0 else {
            throw FinishInboxError.storage(String(cString: strerror(errno)))
        }
        _ = Darwin.chmod(destination.path, S_IRUSR | S_IWUSR)
    }

    public func removeEvent(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    public func removeTemporaryEvents() throws {
        try prepare()
        let entries = try fileManager.contentsOfDirectory(
            at: paths.events,
            includingPropertiesForKeys: nil,
            options: []
        )
        for entry in entries where entry.lastPathComponent.hasPrefix(".") && entry.pathExtension == "tmp" {
            try? fileManager.removeItem(at: entry)
        }
    }

    public func fileMode(at url: URL) -> Int? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let permissions = attributes[.posixPermissions] as? NSNumber else { return nil }
        return permissions.intValue & 0o777
    }

    private func makePrivateDirectory(_ url: URL) throws {
        do {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            guard Darwin.chmod(url.path, S_IRWXU) == 0 else {
                throw FinishInboxError.storage(String(cString: strerror(errno)))
            }
        } catch let error as FinishInboxError {
            throw error
        } catch {
            throw FinishInboxError.storage(error.localizedDescription)
        }
    }

    private func atomicWrite(_ data: Data, to destination: URL) throws {
        try prepare()
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
        let fd = Darwin.open(temporary.path, O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw FinishInboxError.storage(String(cString: strerror(errno))) }
        var succeeded = false
        defer {
            Darwin.close(fd)
            if !succeeded { _ = Darwin.unlink(temporary.path) }
        }
        try data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            var written = 0
            while written < rawBuffer.count {
                let result = Darwin.write(fd, base.advanced(by: written), rawBuffer.count - written)
                guard result > 0 else { throw FinishInboxError.storage(String(cString: strerror(errno))) }
                written += result
            }
        }
        guard Darwin.fsync(fd) == 0 else { throw FinishInboxError.storage(String(cString: strerror(errno))) }
        guard Darwin.rename(temporary.path, destination.path) == 0 else {
            throw FinishInboxError.storage(String(cString: strerror(errno)))
        }
        succeeded = true
        _ = Darwin.chmod(destination.path, S_IRUSR | S_IWUSR)
        let directoryFD = Darwin.open(destination.deletingLastPathComponent().path, O_RDONLY | O_CLOEXEC)
        if directoryFD >= 0 {
            _ = Darwin.fsync(directoryFD)
            Darwin.close(directoryFD)
        }
    }
}
