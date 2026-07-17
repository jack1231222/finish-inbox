import Foundation

public enum InputValidation {
    private static let eventIDRegex = try! NSRegularExpression(pattern: "^[A-Za-z0-9_-]{1,128}$")
    private static let forbiddenScalars: Set<UInt32> = [
        0x061C, 0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
        0x2066, 0x2067, 0x2068, 0x2069,
    ]

    public static func validateEventID(_ id: String) throws -> String {
        let range = NSRange(id.startIndex..<id.endIndex, in: id)
        guard eventIDRegex.firstMatch(in: id, range: range)?.range == range else {
            throw FinishInboxError.invalidEventID
        }
        return id
    }

    public static func normalizeLabel(_ raw: String) throws -> String {
        let normalized = raw.precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw FinishInboxError.invalidProjectLabel("label is empty")
        }
        guard normalized.count <= 128 else {
            throw FinishInboxError.invalidProjectLabel("label exceeds 128 characters")
        }
        for scalar in normalized.unicodeScalars {
            if CharacterSet.controlCharacters.contains(scalar) || forbiddenScalars.contains(scalar.value) {
                throw FinishInboxError.invalidProjectLabel("control or bidirectional formatting characters are not allowed")
            }
        }
        return normalized
    }
}

public enum DisplayFormatting {
    public static func menuBarLabel(project: String, count: Int) -> String {
        let displayProject = project.count > 12 ? String(project.prefix(12)) + "…" : project
        let displayCount = count > 3 ? "3+" : String(max(0, count))
        let suffix = containsHan(project) ? "完成" : "done"
        return "\(displayProject) · \(displayCount) \(suffix) ✓"
    }

    private static func containsHan(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                return true
            default:
                return false
            }
        }
    }
}
