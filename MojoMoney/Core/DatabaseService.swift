import Foundation
import SQLite3

final class DatabaseService {
    static let shared = DatabaseService()

    private var db: OpaquePointer?

    private var dbPath: String {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MojoMoney", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("mojo.sqlite").path
    }

    init() {
        openDatabase()
        createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Setup

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("[DatabaseService] Failed to open database at \(dbPath)")
        }
    }

    private func createTables() {
        let sql = """
        CREATE TABLE IF NOT EXISTS sync_runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            run_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            module TEXT NOT NULL,
            orders_processed INTEGER,
            matched INTEGER,
            applied INTEGER,
            status TEXT
        );

        CREATE TABLE IF NOT EXISTS sync_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            run_id INTEGER REFERENCES sync_runs(id),
            hd_order_number TEXT,
            hd_invoice_number TEXT,
            hd_amount REAL,
            hd_date TEXT,
            monarch_transaction_id TEXT,
            monarch_amount REAL,
            status TEXT,
            notes_written TEXT,
            tags_applied TEXT,
            error TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_hd_order ON sync_results(hd_order_number);
        CREATE INDEX IF NOT EXISTS idx_monarch_tx ON sync_results(monarch_transaction_id);
        """
        var errmsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errmsg) != SQLITE_OK {
            let msg = errmsg.map { String(cString: $0) } ?? "unknown"
            print("[DatabaseService] Table creation error: \(msg)")
        }
    }

    // MARK: - Sync Runs

    func insertSyncRun(module: String, ordersProcessed: Int, matched: Int, applied: Int, status: String) -> Int64 {
        let sql = "INSERT INTO sync_runs (module, orders_processed, matched, applied, status) VALUES (?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return -1 }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, module, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(ordersProcessed))
        sqlite3_bind_int(stmt, 3, Int32(matched))
        sqlite3_bind_int(stmt, 4, Int32(applied))
        sqlite3_bind_text(stmt, 5, status, -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)
        return sqlite3_last_insert_rowid(db)
    }

    func fetchSyncRuns(module: String? = nil) -> [[String: Any]] {
        let sql = module != nil
            ? "SELECT * FROM sync_runs WHERE module = ? ORDER BY run_at DESC"
            : "SELECT * FROM sync_runs ORDER BY run_at DESC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        if let mod = module { sqlite3_bind_text(stmt, 1, mod, -1, SQLITE_TRANSIENT) }
        var rows: [[String: Any]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(rowDict(stmt: stmt))
        }
        return rows
    }

    // MARK: - Sync Results

    func insertSyncResult(runId: Int64, orderNumber: String?, invoiceNumber: String?,
                          hdAmount: Double, hdDate: String,
                          monarchTxId: String?, monarchAmount: Double?,
                          status: String, notesWritten: String?,
                          tagsApplied: String?, error: String?) {
        let sql = """
        INSERT INTO sync_results
            (run_id, hd_order_number, hd_invoice_number, hd_amount, hd_date,
             monarch_transaction_id, monarch_amount, status, notes_written, tags_applied, error)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, runId)
        bindText(stmt, 2, orderNumber)
        bindText(stmt, 3, invoiceNumber)
        sqlite3_bind_double(stmt, 4, hdAmount)
        sqlite3_bind_text(stmt, 5, hdDate, -1, SQLITE_TRANSIENT)
        bindText(stmt, 6, monarchTxId)
        if let ma = monarchAmount { sqlite3_bind_double(stmt, 7, ma) } else { sqlite3_bind_null(stmt, 7) }
        sqlite3_bind_text(stmt, 8, status, -1, SQLITE_TRANSIENT)
        bindText(stmt, 9, notesWritten)
        bindText(stmt, 10, tagsApplied)
        bindText(stmt, 11, error)
        sqlite3_step(stmt)
    }

    func isAlreadyApplied(orderNumber: String?, monarchTxId: String) -> Bool {
        let sql = "SELECT COUNT(*) FROM sync_results WHERE hd_order_number = ? AND monarch_transaction_id = ? AND status = 'applied'"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, orderNumber)
        sqlite3_bind_text(stmt, 2, monarchTxId, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return false }
        return sqlite3_column_int(stmt, 0) > 0
    }

    func fetchSyncResults(runId: Int64) -> [[String: Any]] {
        let sql = "SELECT * FROM sync_results WHERE run_id = ? ORDER BY id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, runId)
        var rows: [[String: Any]] = []
        while sqlite3_step(stmt) == SQLITE_ROW { rows.append(rowDict(stmt: stmt)) }
        return rows
    }

    // MARK: - Helpers

    private func rowDict(stmt: OpaquePointer?) -> [String: Any] {
        var dict: [String: Any] = [:]
        let count = sqlite3_column_count(stmt)
        for i in 0..<count {
            let name = String(cString: sqlite3_column_name(stmt, i))
            switch sqlite3_column_type(stmt, i) {
            case SQLITE_INTEGER: dict[name] = Int(sqlite3_column_int64(stmt, i))
            case SQLITE_FLOAT:   dict[name] = sqlite3_column_double(stmt, i)
            case SQLITE_TEXT:    dict[name] = String(cString: sqlite3_column_text(stmt, i))
            default: break
            }
        }
        return dict
    }

    private func bindText(_ stmt: OpaquePointer?, _ idx: Int32, _ value: String?) {
        if let v = value {
            sqlite3_bind_text(stmt, idx, v, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, idx)
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
