import Foundation

/// What offset text each clock carries in the dropdown. The menu-bar strip
/// never shows any of it — the strip stays as narrow as the times themselves.
///
/// - `none`: nothing beyond the time, day offset and date.
/// - `utc`: the zone's own UTC offset, e.g. "UTC+09:00".
/// - `relative`: distance from the machine's zone, e.g. "+8h". Note this is a
///   different baseline from the day offset, which stays relative to the
///   primary clock.
public enum OffsetDisplay: String, Codable, CaseIterable, Sendable {
    case none
    case utc
    case relative

    public var title: String {
        switch self {
        case .none: return "None"
        case .utc: return "UTC"
        case .relative: return "From local"
        }
    }
}
