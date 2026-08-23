import Foundation

/// The deterministic project grouping consumed by the menu bar manager.
///
/// Keeping this projection independent from AppKit makes the visible/overflow
/// boundary executable in the package test suite and keeps the UI layer focused
/// on rendering and actions.
public struct MenuBarProjectGroups: Equatable, Sendable {
    public static let defaultVisibleProjectLimit = 6

    public let visible: [String]
    public let overflow: [String]

    public init(
        state: ReminderState,
        visibleLimit: Int = MenuBarProjectGroups.defaultVisibleProjectLimit
    ) {
        let activeProjects = state.counts
            .filter { $0.value > 0 }
            .map(\.key)
            .sorted()
        let safeLimit = max(0, visibleLimit)
        visible = Array(activeProjects.prefix(safeLimit))
        overflow = Array(activeProjects.dropFirst(safeLimit))
    }
}
