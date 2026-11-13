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
        Tile {
            TileHeader(title: "Free up context", note: "\(candidates.count) unused")
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tokens, format: .number)
                        .font(.system(size: 44, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText(value: Double(tokens)))
                        .animation(.snappy(duration: 0.2), value: tokens)
                    Text("tokens your agents load every session, for skills and commands you haven't used in")
                        .prose(13)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .center, spacing: Metrics.spacingL) {
                    Picker("Unused For", selection: $window) {
                        ForEach(CleanupWindow.allCases) { window in
                            Text(window.title).tag(window)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .help("How long a skill can go unused before it's listed")

                    Spacer(minLength: Metrics.spacingS)

                    stat("Unused", candidates.count)
                    stat("Never used", neverUsed)
                    stat("Selected", selected.count)
                }

                Divider()

                HStack(spacing: Metrics.spacingM) {
                    Button(action: remove) {
                        Label(
                            selected.isEmpty ? "Nothing Selected" : "Move \(selected.count) to Trash",
                            systemImage: "trash"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selected.isEmpty || isRemoving)

                    if isRemoving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Everything goes to the Trash, and Undo puts it back.")
                            .prose(12)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
        }

        HStack(alignment: .top, spacing: Metrics.spacingL) {
            Tile {
                TileHeader(title: "Biggest savings")
            } content: {
                CleanupSavingsList(candidates: Array(selected.sorted { $0.tokens > $1.tokens }.prefix(5)))
            }
            Tile {
                TileHeader(title: "How Clove decides")
            } content: {
                CleanupMethodList(report: report, window: window)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value, format: .number)
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(Palette.ink)
            Text(title)
                .prose(11)
                .foregroundStyle(Palette.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}
