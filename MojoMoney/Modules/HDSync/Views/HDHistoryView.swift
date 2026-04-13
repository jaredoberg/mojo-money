import SwiftUI

struct HDHistoryView: View {
    @ObservedObject var vm: HDSyncViewModel
    @State private var searchText = ""
    @State private var expandedRunId: Int? = nil

    var filteredRuns: [SyncRun] {
        guard !searchText.isEmpty else { return vm.syncHistory }
        return vm.syncHistory.filter {
            $0.runAt.formatted().localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if vm.syncHistory.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No Sync History",
                    message: "Completed sync runs will appear here with per-transaction results."
                )
            } else {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.mojoTextSecondary)
                    TextField("Search by date or order number", text: $searchText)
                }
                .padding(MOJOSpacing.sm)
                .background(Color.mojoCard)
                .cornerRadius(MOJORadius.sm)
                .padding([.horizontal, .top], MOJOSpacing.md)

                // Runs list
                ScrollView {
                    LazyVStack(spacing: MOJOSpacing.sm) {
                        ForEach(filteredRuns) { run in
                            SyncRunRow(run: run, isExpanded: expandedRunId == run.id) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedRunId = expandedRunId == run.id ? nil : run.id
                                }
                                if expandedRunId == run.id {
                                    // Load results if not already loaded
                                    if let idx = vm.syncHistory.firstIndex(where: { $0.id == run.id }),
                                       vm.syncHistory[idx].results.isEmpty {
                                        let rows = DatabaseService.shared.fetchSyncResults(runId: Int64(run.id))
                                        vm.syncHistory[idx].results = rows.compactMap { SyncResult.from(dict: $0) }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, MOJOSpacing.md)
                    .padding(.vertical, MOJOSpacing.sm)
                }
                .background(Color.mojoNavy)
            }
        }
        .background(Color.mojoNavy.ignoresSafeArea())
        .navigationTitle("Sync History")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { vm.loadHistory() }
    }
}

struct SyncRunRow: View {
    let run: SyncRun
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(run.runAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline).fontWeight(.semibold)
                        Text("\(run.ordersProcessed) orders · \(run.matched) matched · \(run.applied) applied")
                            .font(.caption).foregroundColor(.mojoTextSecondary)
                    }
                    Spacer()
                    StatusBadge(status: run.status.badgeStatus, label: run.status.rawValue.capitalized)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundColor(.mojoTextSecondary)
                }
                .padding(MOJOSpacing.md)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                if run.results.isEmpty {
                    Text("No detailed results recorded.")
                        .font(.caption).foregroundColor(.mojoTextSecondary)
                        .padding(MOJOSpacing.md)
                } else {
                    VStack(spacing: 0) {
                        ForEach(run.results) { result in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.hdOrderNumber ?? result.hdInvoiceNumber ?? "In-Store")
                                        .font(.caption).fontWeight(.medium)
                                    Text(result.hdDate)
                                        .font(.caption2).foregroundColor(.mojoTextSecondary)
                                }
                                Spacer()
                                Text(String(format: "$%.2f", result.hdAmount))
                                    .font(.caption).foregroundColor(.mojoTeal)
                                StatusBadge(status: result.status.badgeStatus, label: result.status.displayLabel)
                            }
                            .padding(.horizontal, MOJOSpacing.md)
                            .padding(.vertical, 6)
                            Divider().padding(.leading, MOJOSpacing.md)
                        }
                    }
                }
            }
        }
        .background(Color.mojoCard)
        .cornerRadius(MOJORadius.md)
    }
}
