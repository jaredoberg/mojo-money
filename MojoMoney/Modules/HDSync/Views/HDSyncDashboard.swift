import SwiftUI

@MainActor
class HDSyncViewModel: ObservableObject {
    // Parse state
    @Published var summaryCSVPath: String? = nil
    @Published var detailsCSVPath: String? = nil
    @Published var parsedTransactions: [HDTransaction] = []
    @Published var parsedLineItemCount = 0
    @Published var parsedCards: [String] = []
    @Published var parsedJobNames: [String] = []
    @Published var dateRange: (from: String, to: String)? = nil

    // Match state
    @Published var matchResults: [MatchResult] = []
    @Published var monarchTransactions: [MonarchTransaction] = []

    // Sync state
    @Published var lastRunId: Int64? = nil
    @Published var syncHistory: [SyncRun] = []

    // UI state
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    // Computed
    var orderCount: Int { parsedTransactions.count }
    var matchedCount: Int { matchResults.filter { $0.status == .matched || $0.status == .applied }.count }
    var ambiguousCount: Int { matchResults.filter { $0.status == .ambiguous }.count }
    var unmatchedCount: Int { matchResults.filter { $0.status == .unmatched }.count }
    var totalEnrichedAmount: Double {
        matchResults
            .filter { $0.status == .applied }
            .compactMap { $0.hdTransaction.totalAmount }
            .reduce(0, +)
    }

    func loadHistory() {
        let rows = DatabaseService.shared.fetchSyncRuns(module: "hd_sync")
        syncHistory = rows.compactMap { SyncRun.from(dict: $0) }
    }

    func parseCSVs() async {
        guard let summary = summaryCSVPath, let details = detailsCSVPath else {
            errorMessage = "Please select both CSV files."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let result: ParseCSVResult = try await PythonBridge.shared.run(
                module: "hd_sync",
                action: "parse_csv",
                payload: ["summary_csv_path": summary, "details_csv_path": details]
            )
            parsedTransactions = result.transactions
            parsedLineItemCount = result.lineItemCount
            parsedCards         = result.cards
            parsedJobNames      = result.jobNames
            dateRange           = result.dateRange.map { ($0.from, $0.to) }
            successMessage      = "Parsed \(result.transactionCount) transactions, \(result.lineItemCount) line items."
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchMonarchAndMatch() async {
        guard !parsedTransactions.isEmpty else {
            errorMessage = "Import CSVs first."
            return
        }
        guard let token = MonarchService.shared.sessionToken else {
            errorMessage = "Not connected to Monarch. Check Settings."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            guard let range = dateRange else { throw NSError(domain: "HDSync", code: 0, userInfo: [NSLocalizedDescriptionKey: "No date range"]) }

            // Fetch Monarch transactions
            let monarchResult: MonarchTransactionsResult = try await PythonBridge.shared.run(
                module: "hd_sync",
                action: "get_monarch_transactions",
                payload: ["date_from": range.0, "date_to": range.1, "session_token": token]
            )
            monarchTransactions = monarchResult.transactions

            // Run matching
            let hdDicts = try parsedTransactions.map { tx -> [String: Any] in
                let data = try JSONEncoder().encode(tx)
                return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            }
            let monarchDicts = try monarchTransactions.map { tx -> [String: Any] in
                let data = try JSONEncoder().encode(tx)
                return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            }

            let matchResult: MatchResultsData = try await PythonBridge.shared.run(
                module: "hd_sync",
                action: "match",
                payload: ["hd_transactions": hdDicts, "monarch_transactions": monarchDicts]
            )
            matchResults = matchResult.results
            successMessage = "Matched \(matchResult.matched) · Ambiguous \(matchResult.ambiguous) · Unmatched \(matchResult.unmatched)"
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func applySync(dryRun: Bool) async {
        guard !matchResults.isEmpty else {
            errorMessage = "Run matching first."
            return
        }
        guard let token = MonarchService.shared.sessionToken else {
            errorMessage = "Not connected to Monarch."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let matchDicts = try matchResults
                .filter { $0.status == .matched }
                .map { result -> [String: Any] in
                    let data = try JSONEncoder().encode(result)
                    return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                }

            let applyResult: ApplyResult = try await PythonBridge.shared.run(
                module: "hd_sync",
                action: dryRun ? "dry_run" : "apply",
                payload: ["matches": matchDicts, "session_token": token, "dry_run": dryRun]
            )

            if !dryRun {
                // Record to DB
                let runId = DatabaseService.shared.insertSyncRun(
                    module: "hd_sync",
                    ordersProcessed: orderCount,
                    matched: matchedCount,
                    applied: applyResult.applied,
                    status: applyResult.status
                )
                lastRunId = runId
                loadHistory()
            }
            successMessage = dryRun
                ? "Dry run: \(applyResult.applied) transactions would be updated."
                : "Applied \(applyResult.applied) transactions."
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Decodable response types

struct ParseCSVResult: Decodable {
    let transactionCount: Int
    let lineItemCount: Int
    let dateRange: DateRange?
    let cards: [String]
    let jobNames: [String]
    let transactions: [HDTransaction]

    struct DateRange: Decodable {
        let from: String
        let to: String
    }

    enum CodingKeys: String, CodingKey {
        case transactionCount = "transaction_count"
        case lineItemCount    = "line_item_count"
        case dateRange        = "date_range"
        case cards, jobNames  = "job_names"
        case transactions
    }
}

struct MonarchTransactionsResult: Decodable {
    let transactions: [MonarchTransaction]
}

struct MatchResultsData: Decodable {
    let results: [MatchResult]
    let matched: Int
    let ambiguous: Int
    let unmatched: Int
}

struct ApplyResult: Decodable {
    let applied: Int
    let status: String
    let errors: [String]
}

// MARK: - Dashboard View

struct HDSyncDashboard: View {
    @StateObject private var vm = HDSyncViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MOJOSpacing.lg) {

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.mojoTeal)
                        Text("HD Sync")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Text("Enrich Monarch transactions with Home Depot Pro purchase details")
                        .font(.subheadline)
                        .foregroundColor(.mojoTextSecondary)
                }
                .padding(.horizontal, MOJOSpacing.lg)
                .padding(.top, MOJOSpacing.lg)

                // Action buttons
                HStack(spacing: MOJOSpacing.sm) {
                    NavigationLink {
                        HDImportView(vm: vm)
                    } label: {
                        Label("Import CSVs", systemImage: "square.and.arrow.down")
                            .font(.subheadline).fontWeight(.semibold)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Color.mojoTeal)
                            .foregroundColor(.white)
                            .cornerRadius(MOJORadius.sm)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        HDMatchView(vm: vm)
                    } label: {
                        Label("Match", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline).fontWeight(.semibold)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Color.mojoCard)
                            .foregroundColor(.mojoTeal)
                            .cornerRadius(MOJORadius.sm)
                            .overlay(RoundedRectangle(cornerRadius: MOJORadius.sm)
                                .strokeBorder(Color.mojoTeal.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.parsedTransactions.isEmpty)

                    NavigationLink {
                        HDSyncPreviewView(vm: vm)
                    } label: {
                        Label("Sync Preview", systemImage: "eye")
                            .font(.subheadline).fontWeight(.semibold)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Color.mojoCard)
                            .foregroundColor(vm.matchResults.isEmpty ? .mojoTextSecondary : .mojoTeal)
                            .cornerRadius(MOJORadius.sm)
                            .overlay(RoundedRectangle(cornerRadius: MOJORadius.sm)
                                .strokeBorder(vm.matchResults.isEmpty ? Color.mojoTextSecondary.opacity(0.2) : Color.mojoTeal.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.matchResults.isEmpty)

                    Spacer()

                    NavigationLink {
                        HDHistoryView(vm: vm)
                    } label: {
                        Label("History", systemImage: "clock")
                            .font(.subheadline)
                            .foregroundColor(.mojoTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, MOJOSpacing.lg)

                // Stat cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                    GridItem(.flexible()), GridItem(.flexible())], spacing: MOJOSpacing.sm) {
                    StatCard(value: "\(vm.orderCount)", label: "Orders")
                    StatCard(value: "\(vm.parsedLineItemCount)", label: "Line Items")
                    StatCard(value: "\(vm.matchedCount)", label: "Matched", valueColor: .mojoSuccess)
                    StatCard(value: String(format: "$%.0f", vm.totalEnrichedAmount), label: "Enriched", valueColor: .mojoTeal)
                }
                .padding(.horizontal, MOJOSpacing.lg)

                // Match status breakdown
                if !vm.matchResults.isEmpty {
                    VStack(alignment: .leading, spacing: MOJOSpacing.sm) {
                        SectionHeader(title: "Match Status")
                        HStack(spacing: MOJOSpacing.md) {
                            StatusBadge(status: .success, label: "\(vm.matchedCount) Matched")
                            StatusBadge(status: .warning, label: "\(vm.ambiguousCount) Ambiguous")
                            StatusBadge(status: .error,   label: "\(vm.unmatchedCount) Unmatched")
                        }
                    }
                    .padding(.horizontal, MOJOSpacing.lg)
                }

                // Messages
                if let err = vm.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(err).font(.subheadline)
                    }
                    .foregroundColor(.mojoDestructive)
                    .padding(MOJOSpacing.md)
                    .background(Color.mojoDestructive.opacity(0.1))
                    .cornerRadius(MOJORadius.md)
                    .padding(.horizontal, MOJOSpacing.lg)
                }

                if let success = vm.successMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(success).font(.subheadline)
                    }
                    .foregroundColor(.mojoSuccess)
                    .padding(MOJOSpacing.md)
                    .background(Color.mojoSuccess.opacity(0.1))
                    .cornerRadius(MOJORadius.md)
                    .padding(.horizontal, MOJOSpacing.lg)
                }

                Spacer(minLength: MOJOSpacing.xl)
            }
        }
        .background(Color.mojoNavy.ignoresSafeArea())
        .navigationTitle("HD Sync")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { vm.loadHistory() }
        .overlay {
            if vm.isLoading {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.mojoTeal)
                            .scaleEffect(1.5)
                        Text("Working...")
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Color.mojoCard)
                    .cornerRadius(MOJORadius.lg)
                }
            }
        }
    }
}
