import Foundation

enum SyncRunStatus: String, Codable {
    case completed
    case partial
    case failed

    var badgeStatus: BadgeStatus {
        switch self {
        case .completed: return .success
        case .partial:   return .warning
        case .failed:    return .error
        }
    }
}

struct SyncRun: Identifiable {
    let id: Int
    let runAt: Date
    let module: String
    let ordersProcessed: Int
    let matched: Int
    let applied: Int
    let status: SyncRunStatus
    var results: [SyncResult] = []

    static func from(dict: [String: Any]) -> SyncRun? {
        guard let id = dict["id"] as? Int else { return nil }
        let runAtStr = dict["run_at"] as? String ?? ""
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withSpaceBetweenDateAndTime]
        let runAt = formatter.date(from: runAtStr) ?? Date()
        return SyncRun(
            id: id,
            runAt: runAt,
            module: dict["module"] as? String ?? "",
            ordersProcessed: dict["orders_processed"] as? Int ?? 0,
            matched: dict["matched"] as? Int ?? 0,
            applied: dict["applied"] as? Int ?? 0,
            status: SyncRunStatus(rawValue: dict["status"] as? String ?? "") ?? .failed
        )
    }
}

struct SyncResult: Identifiable {
    let id: Int
    let runId: Int
    let hdOrderNumber: String?
    let hdInvoiceNumber: String?
    let hdAmount: Double
    let hdDate: String
    let monarchTransactionId: String?
    let monarchAmount: Double?
    let status: MatchStatus
    let notesWritten: String?
    let tagsApplied: String?
    let error: String?

    static func from(dict: [String: Any]) -> SyncResult? {
        guard let id = dict["id"] as? Int else { return nil }
        return SyncResult(
            id: id,
            runId: dict["run_id"] as? Int ?? 0,
            hdOrderNumber: dict["hd_order_number"] as? String,
            hdInvoiceNumber: dict["hd_invoice_number"] as? String,
            hdAmount: dict["hd_amount"] as? Double ?? 0,
            hdDate: dict["hd_date"] as? String ?? "",
            monarchTransactionId: dict["monarch_transaction_id"] as? String,
            monarchAmount: dict["monarch_amount"] as? Double,
            status: MatchStatus(rawValue: dict["status"] as? String ?? "") ?? .unmatched,
            notesWritten: dict["notes_written"] as? String,
            tagsApplied: dict["tags_applied"] as? String,
            error: dict["error"] as? String
        )
    }
}
