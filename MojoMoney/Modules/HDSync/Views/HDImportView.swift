import SwiftUI
import UniformTypeIdentifiers

struct HDImportView: View {
    @ObservedObject var vm: HDSyncViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MOJOSpacing.lg) {

                VStack(alignment: .leading, spacing: 4) {
                    Text("Import Home Depot CSVs")
                        .font(.title2).fontWeight(.bold)
                    Text("Export both files from the Home Depot Pro Purchase Tracking portal.")
                        .font(.subheadline)
                        .foregroundColor(.mojoTextSecondary)
                }
                .padding(.top, MOJOSpacing.md)

                // Two drop zones
                HStack(spacing: MOJOSpacing.md) {
                    CSVDropZone(
                        title: "Summary CSV",
                        subtitle: "Orders + totals",
                        filePath: $vm.summaryCSVPath,
                        fileTag: .summary
                    )
                    CSVDropZone(
                        title: "Details CSV",
                        subtitle: "Line items + SKUs",
                        filePath: $vm.detailsCSVPath,
                        fileTag: .details
                    )
                }

                // Parse summary
                if let summary = vm.summaryCSVPath, let details = vm.detailsCSVPath {
                    VStack(alignment: .leading, spacing: 8) {
                        if vm.parsedTransactions.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.mojoSuccess)
                                Text("Both files selected — ready to parse.")
                                    .foregroundColor(.mojoTextSecondary)
                            }
                            .font(.subheadline)
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Image(systemName: "checkmark.circle.fill").foregroundColor(.mojoSuccess)
                                    Text("Parsed: \(vm.orderCount) transactions · \(vm.parsedLineItemCount) line items")
                                        .fontWeight(.medium)
                                }
                                if !vm.parsedCards.isEmpty {
                                    Text("Cards: \(vm.parsedCards.joined(separator: " · "))")
                                        .font(.caption).foregroundColor(.mojoTextSecondary)
                                }
                                if !vm.parsedJobNames.isEmpty {
                                    Text("Jobs: \(vm.parsedJobNames.joined(separator: " · "))")
                                        .font(.caption).foregroundColor(.mojoTextSecondary)
                                }
                                if let range = vm.dateRange {
                                    Text("Date range: \(range.from) — \(range.to)")
                                        .font(.caption).foregroundColor(.mojoTextSecondary)
                                }
                            }
                        }
                    }
                    .padding(MOJOSpacing.md)
                    .background(Color.mojoCard)
                    .cornerRadius(MOJORadius.md)
                }

                if let err = vm.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.mojoDestructive)
                        .padding(MOJOSpacing.sm)
                        .background(Color.mojoDestructive.opacity(0.1))
                        .cornerRadius(MOJORadius.sm)
                }

                // Actions
                HStack(spacing: MOJOSpacing.sm) {
                    MOJOButton(title: "Parse CSVs", style: .primary,
                               isLoading: vm.isLoading,
                               systemImage: "arrow.clockwise") {
                        Task { await vm.parseCSVs() }
                    }
                    .disabled(vm.summaryCSVPath == nil || vm.detailsCSVPath == nil)

                    if !vm.parsedTransactions.isEmpty {
                        NavigationLink("Preview Transactions →") {
                            HDMatchView(vm: vm)
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline).fontWeight(.semibold)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .foregroundColor(.mojoTeal)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, MOJOSpacing.lg)
        }
        .background(Color.mojoNavy.ignoresSafeArea())
        .navigationTitle("Import CSVs")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Drop Zone

enum CSVFileTag { case summary, details }

struct CSVDropZone: View {
    let title: String
    let subtitle: String
    @Binding var filePath: String?
    let fileTag: CSVFileTag

    @State private var isTargeted = false
    @State private var showFilePicker = false

    var fileName: String? {
        filePath.map { URL(fileURLWithPath: $0).lastPathComponent }
    }

    var body: some View {
        VStack(spacing: MOJOSpacing.sm) {
            Image(systemName: filePath == nil ? "doc.badge.plus" : "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(filePath == nil ? .mojoTextSecondary : .mojoSuccess)

            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.mojoTextSecondary)

            if let name = fileName {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.mojoTeal)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 8)
            } else {
                Text("Drop file here or")
                    .font(.caption)
                    .foregroundColor(.mojoTextSecondary)
            }

            MOJOButton(title: "Browse", style: .secondary) {
                showFilePicker = true
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(MOJOSpacing.md)
        .background(isTargeted ? Color.mojoTeal.opacity(0.1) : Color.mojoCard)
        .cornerRadius(MOJORadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: MOJORadius.lg)
                .strokeBorder(
                    isTargeted ? Color.mojoTeal : (filePath != nil ? Color.mojoSuccess.opacity(0.5) : Color.mojoTextSecondary.opacity(0.2)),
                    style: StrokeStyle(lineWidth: 1.5, dash: filePath == nil ? [6] : [])
                )
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            providers.first?.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async { filePath = url.path }
                }
            }
            return true
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.commaSeparatedText, .text]) { result in
            if case .success(let url) = result {
                _ = url.startAccessingSecurityScopedResource()
                filePath = url.path
            }
        }
    }
}
