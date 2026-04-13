import SwiftUI

struct HDSettingsView: View {
    @AppStorage("hd_autoTag_homeDepotReceipt") private var autoTagHomeDepotReceipt = true
    @AppStorage("hd_autoTag_jobName")          private var autoTagJobName = true
    @AppStorage("hd_autoTag_department")       private var autoTagDepartment = true
    @AppStorage("hd_notesMaxChars")            private var notesMaxChars = 900
    @AppStorage("hd_dateWindowDays")           private var dateWindowDays = 3
    @AppStorage("hd_amountToleranceCents")     private var amountToleranceCents = 2 // $0.02

    var body: some View {
        Form {
            Section("Matching") {
                LabeledContent("Date Window") {
                    Stepper("\(dateWindowDays) days", value: $dateWindowDays, in: 0...7)
                }
                LabeledContent("Amount Tolerance") {
                    Stepper("$0.0\(amountToleranceCents)", value: $amountToleranceCents, in: 0...10)
                }
            }

            Section("Auto-Tags") {
                Toggle("Home Depot Receipt", isOn: $autoTagHomeDepotReceipt)
                Toggle("HD-[JobName]", isOn: $autoTagJobName)
                Toggle("Primary Department", isOn: $autoTagDepartment)
            }

            Section("Notes") {
                LabeledContent("Max Characters") {
                    Stepper("\(notesMaxChars)", value: $notesMaxChars, in: 500...1000, step: 50)
                }
                Text("Monarch note limit is ~1,000 characters. Notes are truncated gracefully.")
                    .font(.caption)
                    .foregroundColor(.mojoTextSecondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("HD Sync Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
