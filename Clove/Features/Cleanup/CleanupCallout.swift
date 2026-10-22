import SwiftUI

struct CleanupCallout: View {
    let candidates: [CleanupCandidate]
    let selected: [CleanupCandidate]
    let report: AgentUsageScanner.Report
    @Binding var window: CleanupWindow
    let isRemoving: Bool
    let remove: () -> Void

    private var tokens: Int {
        selected.reduce(0) { $0 + $1.tokens }
    }

    private var neverUsed: Int {
        candidates.count { $0.lastUsed == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            Text("Free up context")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(tokens, format: .number)
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(tokens)))
                .animation(.snappy(duration: 0.2), value: tokens)

            Text("tokens your agents load in every session, for skills and commands you haven't used in")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Unused For", selection: $window) {
                ForEach(CleanupWindow.allCases) { window in
                    Text(window.title).tag(window)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.top, Metrics.spacingXS)
            .help("How long a skill can go unused before it's listed")
        }

        HStack(alignment: .top, spacing: Metrics.spacingXL) {
            MarketplaceStat(title: "Unused") {
                Text(candidates.count, format: .number)
            }
            MarketplaceStat(title: "Never Used") {
                Text(neverUsed, format: .number)
            }
            MarketplaceStat(title: "Selected") {
                Text(selected.count, format: .number)
            }
        }

        HStack(spacing: Metrics.spacingM) {
            Button(action: remove) {
                Label(
                    selected.isEmpty ? "Nothing Selected" : "Move \(selected.count) to Trash",
                    systemImage: "trash"
                )
                .padding(.horizontal, Metrics.spacingXS)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(selected.isEmpty || isRemoving)

            if isRemoving {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text("You can undo this.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }

        SkillDetailSection(title: "Biggest Savings") {
            CleanupSavingsList(candidates: Array(selected.sorted { $0.tokens > $1.tokens }.prefix(5)))
        }

        SkillDetailSection(title: "How Clove Decides") {
            CleanupMethodList(report: report, window: window)
        }
    }
}
