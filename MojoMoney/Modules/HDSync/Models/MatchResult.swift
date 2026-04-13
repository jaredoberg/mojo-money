import Foundation

enum MatchStatus: String, Codable {
    case matched
    case ambiguous
    case unmatched
    case applied
    case skipped

    var displayLabel: String {
        switch self {
        case .matched:   return "Matched"
        case .ambiguous: return "Ambiguous"
        case .unmatched: return "Unmatched"
        case .applied:   return "Applied"
        case .skipped:   return "Skipped"
        }
    }

    var badgeStatus: BadgeStatus {
        switch self {
        case .matched:   return .success
        case .ambiguous: return .warning
        case .unmatched: return .error
        case .applied:   return .info
        case .skipped:   return .info
        }
    }
}

struct MonarchTransaction: Codable, Identifiable {
    let id: String
    let date: String
    let amount: Double
    let merchant: String
    let category: String?
    let notes: String?

    var formattedAmount: String { String(format: "$%.2f", Swift.abs(amount)) }
}

struct MatchResult: Codable, Identifiable {
    let hdTransaction: HDTransaction
    var monarchTransaction: MonarchTransaction?
    var status: MatchStatus
    let confidence: Double
    let candidates: [MonarchTransaction]
    var isUserOverride: Bool

    var id: String { hdTransaction.id }

    var proposedNotes: String?
    var proposedTags: [String]

    enum CodingKeys: String, CodingKey {
        case hdTransaction   = "hd_order"
        case monarchTransaction = "monarch_tx"
        case status, confidence, candidates
        case isUserOverride  = "is_user_override"
        case proposedNotes   = "proposed_notes"
        case proposedTags    = "proposed_tags"
    }
}
