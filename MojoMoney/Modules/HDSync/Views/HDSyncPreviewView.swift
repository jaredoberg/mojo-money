import SwiftUI

struct HDSyncPreviewView: View {
    @ObservedObject var vm: HDSyncViewModel
    @State private var selectedResultId: String? = nil
    @State private var isDryRunning = false
    @State private var dryRunOutput: String? = nil

    var matchedResults: [MatchResult] {
        vm.matchResults.filter { $0.status == .matched || $0.status == .applied }
    }

    var selectedResult: MatchResult? {
        guard let id = selectedResultId else { return matchedResults.first }
        return matchedResults.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Summary bar
            HStack {
                Text("\(matchedResults.count) transactions will be updated")
                    .font(.subheadline)
                    .foregroundColor(.mojoTextSecondary)
                Spacer()

                MOJOButton(title: "Dry Run — Export Preview", style: .ghost,
                           isLoading: isDryRunning) {
                    Task {
                        isDryRunning = true
                        await vm.applySync(dryRun: true)
                        dryRunOutput = vm.successMessage
                        isDryRunning = false
                    }
                }
                MOJOButton(title: "Apply All", style: .primary,
                           isLoading: vm.isLoading) {
                    Task { await vm.applySync(dryRun: false) }
                }
                .disabled(matchedResults.isEmpty)
            }
            .padding(.horizontal, MOJOSpacing.lg)
            .padding(.vertical, MOJOSpacing.md)
            .background(Color.mojoCard)

            if let msg = dryRunOutput ?? vm.successMessage {
                Text(msg)
                    .font(.caption).foregroundColor(.mojoSuccess)
                    .padding(.horizontal, MOJOSpacing.lg)
                    .padding(.top, MOJOSpacing.xs)
            }

            if matchedResults.isEmpty {
                EmptyStateView(
                    icon: "arrow.triangle.2.circlepath",
                    title: "No Matched Transactions",
                    message: "Run matching first. Only matched transactions can be previewed and synced."
                )
            } else {
                #if os(macOS)
                HSplitView {
                    // Left: transaction list
                    transactionList
                        .frame(minWidth: 240, maxWidth: 320)

                    // Right: diff view
                    diffView
                        .frame(minWidth: 400)
                }
                #else
                VStack {
                    if selectedResult != nil {
                        diffView
                    } else {
                        transactionList
                    }
                }
                #endif
            }
        }
        .background(Color.mojoNavy.ignoresSafeArea())
        .navigationTitle("Sync Preview")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    var transactionList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(matchedResults) { result in
                    Button {
                        selectedResultId = result.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.hdTransaction.displayId)
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text(result.hdTransaction.date)
                                    .font(.caption).foregroundColor(.mojoTextSecondary)
                            }
                            Spacer()
                            Text(result.hdTransaction.formattedAmount)
                                .font(.caption).fontWeight(.semibold).foregroundColor(.mojoTeal)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(selectedResultId == result.id ? Color.mojoTeal.opacity(0.15) : Color.mojoCard)
                        .cornerRadius(MOJORadius.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(MOJOSpacing.sm)
        }
        .background(Color.mojoNavy.opacity(0.5))
    }

    var diffView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MOJOSpacing.lg) {
                if let result = selectedResult {
                    // Current state
                    VStack(alignment: .leading, spacing: MOJOSpacing.sm) {
                        Text("CURRENT STATE")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(.mojoTextSecondary).tracking(1.2)
                        if let tx = result.monarchTransaction {
                            DiffPane(
                                content: tx.notes ?? "(no notes)",
                                tags: [],
                                accentColor: .mojoTextSecondary
                            )
                        }
                    }

                    // Arrow
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.down")
                            .font(.title3)
                            .foregroundColor(.mojoTeal)
                        Spacer()
                    }

                    // Proposed state
                    VStack(alignment: .leading, spacing: MOJOSpacing.sm) {
                        Text("AFTER SYNC")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(.mojoTeal).tracking(1.2)
                        DiffPane(
                            content: result.proposedNotes ?? "(notes will be generated at sync time)",
                            tags: result.proposedTags,
                            accentColor: .mojoTeal,
                            isHighlighted: true
                        )
                    }
                } else {
                    Text("Select a transaction to preview")
                        .foregroundColor(.mojoTextSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(MOJOSpacing.lg)
        }
    }
}

struct DiffPane: View {
    let content: String
    let tags: [String]
    let accentColor: Color
    var isHighlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: MOJOSpacing.sm) {
            Text(content)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(isHighlighted ? .primary : .mojoTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(MOJOSpacing.md)
                .background(isHighlighted ? accentColor.opacity(0.08) : Color.mojoNavy.opacity(0.5))
                .cornerRadius(MOJORadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: MOJORadius.sm)
                        .strokeBorder(accentColor.opacity(isHighlighted ? 0.3 : 0.1), lineWidth: 1)
                )

            if !tags.isEmpty {
                HStack(spacing: 4) {
                    Text("Tags:")
                        .font(.caption2).foregroundColor(.mojoTextSecondary)
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2).fontWeight(.medium)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(accentColor.opacity(0.15))
                            .foregroundColor(accentColor)
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
}
