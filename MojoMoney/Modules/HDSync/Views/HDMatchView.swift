import SwiftUI

struct HDMatchView: View {
    @ObservedObject var vm: HDSyncViewModel
    @State private var filterStatus: MatchStatus? = nil
    @State private var expandedId: String? = nil

    var filteredResults: [MatchResult] {
        guard let filter = filterStatus else { return vm.matchResults }
        return vm.matchResults.filter { $0.status == filter }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Toolbar
            HStack(spacing: MOJOSpacing.sm) {
                MOJOButton(title: "Match All", style: .primary,
                           isLoading: vm.isLoading, systemImage: "arrow.triangle.2.circlepath") {
                    Task { await vm.fetchMonarchAndMatch() }
                }
                .disabled(vm.parsedTransactions.isEmpty)

                MOJOButton(title: "Clear", style: .ghost) {
                    vm.matchResults = []
                    vm.monarchTransactions = []
                }
                .disabled(vm.matchResults.isEmpty)

                Spacer()

                // Filter picker
                Picker("Filter", selection: $filterStatus) {
                    Text("All").tag(MatchStatus?.none)
                    Text("✅ Matched").tag(MatchStatus?.some(.matched))
                    Text("⚠️ Ambiguous").tag(MatchStatus?.some(.ambiguous))
                    Text("❌ Unmatched").tag(MatchStatus?.some(.unmatched))
                    Text("Applied").tag(MatchStatus?.some(.applied))
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 160)
            }
            .padding(.horizontal, MOJOSpacing.lg)
            .padding(.vertical, MOJOSpacing.md)
            .background(Color.mojoCard)

            if let err = vm.errorMessage {
                Text(err)
                    .font(.caption).foregroundColor(.mojoDestructive)
                    .padding(.horizontal, MOJOSpacing.lg)
                    .padding(.top, MOJOSpacing.sm)
            }

            if vm.matchResults.isEmpty {
                if vm.parsedTransactions.isEmpty {
                    EmptyStateView(
                        icon: "square.and.arrow.down",
                        title: "No Transactions Imported",
                        message: "Import CSVs first to run matching."
                    )
                } else {
                    EmptyStateView(
                        icon: "arrow.triangle.2.circlepath",
                        title: "No Match Results",
                        message: "Tap \"Match All\" to fetch Monarch transactions and run matching.",
                        action: { Task { await vm.fetchMonarchAndMatch() } },
                        actionLabel: "Match All"
                    )
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: MOJOSpacing.xs, pinnedViews: []) {
                        ForEach(filteredResults) { result in
                            MatchResultRow(
                                result: result,
                                isExpanded: expandedId == result.id,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedId = expandedId == result.id ? nil : result.id
                                    }
                                },
                                onSelectCandidate: { candidate in
                                    // Allow manual override
                                    if let idx = vm.matchResults.firstIndex(where: { $0.id == result.id }) {
                                        vm.matchResults[idx].monarchTransaction = candidate
                                        vm.matchResults[idx].status = .matched
                                        vm.matchResults[idx].isUserOverride = true
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, MOJOSpacing.md)
                    .padding(.vertical, MOJOSpacing.sm)
                }
                .background(Color.mojoNavy)
            }
        }
        .background(Color.mojoNavy.ignoresSafeArea())
        .navigationTitle("Match (\(vm.matchResults.count))")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Match Result Row

struct MatchResultRow: View {
    let result: MatchResult
    let isExpanded: Bool
    let onTap: () -> Void
    let onSelectCandidate: (MonarchTransaction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Summary row
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Left: HD icon
                    ZStack {
                        Circle().fill(Color(hex: "F96302").opacity(0.15)).frame(width: 36, height: 36)
                        Text("HD").font(.caption2).fontWeight(.black).foregroundColor(Color(hex: "F96302"))
                    }

                    // Center: transaction info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.hdTransaction.displayId)
                            .font(.subheadline).fontWeight(.semibold)
                        HStack(spacing: 6) {
                            Text(result.hdTransaction.date)
                                .font(.caption).foregroundColor(.mojoTextSecondary)
                            Text("·")
                                .foregroundColor(.mojoTextSecondary)
                            Text(result.hdTransaction.displayOrigin)
                                .font(.caption).foregroundColor(.mojoTextSecondary)
                            if let job = result.hdTransaction.jobName {
                                Text("·")
                                    .foregroundColor(.mojoTextSecondary)
                                Text(job)
                                    .font(.caption).foregroundColor(.mojoTeal)
                            }
                        }
                    }

                    Spacer()

                    // Right: amount + status
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(result.hdTransaction.formattedAmount)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(amountColor)
                        StatusBadge(status: result.status.badgeStatus, label: result.status.displayLabel)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundColor(.mojoTextSecondary)
                }
                .padding(.horizontal, MOJOSpacing.md)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                VStack(alignment: .leading, spacing: MOJOSpacing.sm) {
                    Divider()

                    // Monarch match info
                    if let tx = result.monarchTransaction {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monarch Match")
                                .font(.caption).fontWeight(.semibold).foregroundColor(.mojoTextSecondary)
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tx.merchant).font(.subheadline).fontWeight(.medium)
                                    Text("\(tx.date) · \(tx.formattedAmount)")
                                        .font(.caption).foregroundColor(.mojoTextSecondary)
                                }
                                Spacer()
                                if result.isUserOverride {
                                    StatusBadge(status: .info, label: "Manual")
                                }
                            }
                        }
                        .padding(.horizontal, MOJOSpacing.md)
                    } else if result.status == .unmatched {
                        Text("No Monarch transaction found within ±$0.02 / ±3 days")
                            .font(.caption).foregroundColor(.mojoDestructive)
                            .padding(.horizontal, MOJOSpacing.md)
                    }

                    // Ambiguous candidates
                    if result.status == .ambiguous && !result.candidates.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Choose a match:")
                                .font(.caption).fontWeight(.semibold).foregroundColor(.mojoWarning)
                                .padding(.horizontal, MOJOSpacing.md)
                            ForEach(result.candidates) { candidate in
                                Button {
                                    onSelectCandidate(candidate)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(candidate.merchant).font(.caption).fontWeight(.medium)
                                            Text("\(candidate.date) · \(candidate.formattedAmount)")
                                                .font(.caption2).foregroundColor(.mojoTextSecondary)
                                        }
                                        Spacer()
                                        Text("Select")
                                            .font(.caption2).fontWeight(.semibold).foregroundColor(.mojoTeal)
                                    }
                                    .padding(.horizontal, MOJOSpacing.md)
                                    .padding(.vertical, 6)
                                    .background(Color.mojoNavy.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Line item preview (top 3)
                    let items = result.hdTransaction.lineItems.prefix(3)
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Line Items (\(result.hdTransaction.lineItems.count))")
                                .font(.caption).fontWeight(.semibold).foregroundColor(.mojoTextSecondary)
                                .padding(.horizontal, MOJOSpacing.md)
                            ForEach(Array(items)) { item in
                                HStack {
                                    Text(item.skuDescription)
                                        .font(.caption2).lineLimit(1)
                                    Spacer()
                                    Text(item.formattedPrice)
                                        .font(.caption2).foregroundColor(.mojoTeal)
                                }
                                .padding(.horizontal, MOJOSpacing.md)
                            }
                            if result.hdTransaction.lineItems.count > 3 {
                                Text("+ \(result.hdTransaction.lineItems.count - 3) more")
                                    .font(.caption2).foregroundColor(.mojoTextSecondary)
                                    .padding(.horizontal, MOJOSpacing.md)
                            }
                        }
                    }

                    Spacer(minLength: MOJOSpacing.sm)
                }
                .background(Color.mojoNavy.opacity(0.4))
            }
        }
        .background(Color.mojoCard)
        .cornerRadius(MOJORadius.md)
    }

    var amountColor: Color {
        switch result.status {
        case .matched, .applied: return .mojoTeal
        case .ambiguous:         return .mojoWarning
        case .unmatched:         return .mojoTextSecondary
        case .skipped:           return .mojoTextSecondary
        }
    }
}
