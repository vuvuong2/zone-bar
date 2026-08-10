import Foundation

/// Single switch that drives both the menu-bar strip and the dropdown layout.
///
/// - `flat`: every clock is rendered inline in the menu bar, and the dropdown
///   is one flat list.
/// - `grouped`: the menu bar shows only the primary clock, and the dropdown is
///   split into region sections.
public enum DisplayMode: String, Codable, CaseIterable, Sendable {
    case flat
    case grouped

    public var title: String {
        switch self {
        case .flat: return "Flat"
        case .grouped: return "Grouped"
        }
    }

    public var explanation: String {
        switch self {
        case .flat: return "All clocks inline in the menu bar, one flat list."
        case .grouped: return "Only the primary clock in the menu bar, grouped by region."
        }
    }
}
