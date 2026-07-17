import Foundation

public let finishInboxSchemaVersion = 1

public struct CompletionEvent: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let project: String
    public let createdAt: Date

    public init(
        schemaVersion: Int = finishInboxSchemaVersion,
        id: String,
        project: String,
        createdAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.project = project
        self.createdAt = createdAt
    }
}

public struct ReminderState: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var counts: [String: Int]
    public var processedEvents: [String: Date]

    public init(
        schemaVersion: Int = finishInboxSchemaVersion,
        counts: [String: Int] = [:],
        processedEvents: [String: Date] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.counts = counts
        self.processedEvents = processedEvents
    }
}

public struct ProjectConfig: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var mappings: [String: String]

    public init(
        schemaVersion: Int = finishInboxSchemaVersion,
        mappings: [String: String] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.mappings = mappings
    }
}

public struct ReconcileResult: Equatable, Sendable {
    public let accepted: Int
    public let duplicates: Int
    public let quarantined: Int
    public let state: ReminderState
}

public enum FinishInboxError: Error, Equatable, LocalizedError, Sendable {
    case invalidEventID
    case invalidProjectLabel(String)
    case mappingMissing
    case malformedConfig
    case malformedState
    case unsupportedSchema(String, Int)
    case invalidState(String)
    case cannotOpenLock
    case cannotAcquireLock
    case storage(String)

    public var errorDescription: String? {
        switch self {
        case .invalidEventID:
            return "Event ID must match [A-Za-z0-9_-]{1,128}."
        case .invalidProjectLabel(let reason):
            return "Invalid project label: \(reason)"
        case .mappingMissing:
            return "No private project mapping exists for the current directory. Run `finish-inbox map <label>` first."
        case .malformedConfig:
            return "The configuration file is malformed and was left unchanged."
        case .malformedState:
            return "The state file is malformed and was left unchanged."
        case .unsupportedSchema(let kind, let version):
            return "Unsupported \(kind) schema version: \(version)."
        case .invalidState(let reason):
            return "Invalid state: \(reason)"
        case .cannotOpenLock:
            return "Could not open the private lock file."
        case .cannotAcquireLock:
            return "Another manager is already running for this state root."
        case .storage(let reason):
            return "Storage error: \(reason)"
        }
    }
}
