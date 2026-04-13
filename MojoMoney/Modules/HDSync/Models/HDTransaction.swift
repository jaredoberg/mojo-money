import Foundation

struct HDTransaction: Codable, Identifiable {
    let orderNumber: String?
    let invoiceNumber: String?
    let date: String               // "YYYY-MM-DD"
    let totalAmount: Double
    let isReturn: Bool
    let jobName: String?
    let orderOrigin: String
    let cardAlias: String?
    let purchaser: String?
    var lineItems: [HDLineItem]

    var id: String { orderNumber ?? invoiceNumber ?? "\(date)-\(totalAmount)" }

    var displayId: String {
        if let on = orderNumber, !on.isEmpty { return on }
        if let inv = invoiceNumber, !inv.isEmpty { return "Inv: \(inv)" }
        return "In-Store"
    }

    var displayOrigin: String {
        orderOrigin.lowercased() == "online" ? "Online" : orderOrigin
    }

    var formattedAmount: String {
        let abs = Swift.abs(totalAmount)
        return String(format: "%@$%.2f", isReturn ? "+" : "-", abs)
    }

    enum CodingKeys: String, CodingKey {
        case orderNumber  = "order_number"
        case invoiceNumber = "invoice_number"
        case date
        case totalAmount  = "total_amount"
        case isReturn     = "is_return"
        case jobName      = "job_name"
        case orderOrigin  = "order_origin"
        case cardAlias    = "card_alias"
        case purchaser
        case lineItems    = "line_items"
    }
}
