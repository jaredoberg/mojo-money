import Foundation

struct HDLineItem: Codable, Identifiable {
    let date: String
    let orderNumber: String?
    let invoiceNumber: String?
    let skuNumber: String?
    let skuDescription: String
    let quantity: Double
    let unitPrice: Double
    let netUnitPrice: Double
    let extendedRetail: Double
    let departmentName: String
    let className: String?
    let subclassName: String?
    let jobName: String?
    let purchaser: String?

    var id: String {
        "\(orderNumber ?? "")-\(invoiceNumber ?? "")-\(skuNumber ?? skuDescription)"
    }

    var formattedPrice: String { String(format: "$%.2f", extendedRetail) }

    enum CodingKeys: String, CodingKey {
        case date
        case orderNumber   = "order_number"
        case invoiceNumber = "invoice_number"
        case skuNumber     = "sku_number"
        case skuDescription = "sku_description"
        case quantity
        case unitPrice     = "unit_price"
        case netUnitPrice  = "net_unit_price"
        case extendedRetail = "extended_retail"
        case departmentName = "department_name"
        case className     = "class_name"
        case subclassName  = "subclass_name"
        case jobName       = "job_name"
        case purchaser
    }
}
