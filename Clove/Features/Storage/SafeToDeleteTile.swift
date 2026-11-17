import SwiftUI

/// Leftover data you can remove without worrying, each with what it is and
/// what happens after. Everything goes to the Trash, so it can come back.
struct SafeToDeleteTile: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let storage = model.storage
        let findings = storage.tempFindings.value ?? []
        let total = findings.reduce(Int64(0)) { $0 + $1.bytes }

        Tile {
            TileHeader(title: "Safe to delete", note: findings.isEmpty ? nil : StorageFormat.gb(total)) {
                if storage.tempFindings.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Look Again") { Task { await storage.scanTemp() } }
                        .buttonStyle(.link)
                        .prose(12)
                }
            }
        } content: {
            VStack(alignment: .leading, spacing: Metrics.spacingM) {
                if findings.isEmpty {
                    Text(storage.tempFindings.isLoading ? "Looking for leftover files…" : "Nothing worth clearing outside your caches right now.")
                        .prose(13)
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                } else {
                    DividedRows {
                        ForEach(findings) { finding in
                            SafeToDeleteRow(finding: finding)
                        }
                    }
                }
                Text("Caches in ~/Library/Caches are cleared with Clear Caches above. Anything cleared here goes to the Trash first.")
                    .prose(11)
                    .foregroundStyle(Palette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(.easeOut(duration: 0.2), value: findings.map(\.id))
    }
}

private struct SafeToDeleteRow: View {
    @Environment(AppModel.self) private var model
    let finding: TempFinding
    @State private var isConfirming = false

    var body: some View {
        let storage = model.storage
        let isClearing = storage.clearingSpot == finding.id

        HStack(alignment: .top, spacing: Metrics.spacingM) {
            Image(systemName: finding.spot.symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 28, height: 28)
                .background(Palette.surfaceSunken, in: .rect(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Metrics.spacingS) {
                    Text(finding.spot.title)
                        .prose(13, .medium)
                        .foregroundStyle(Palette.ink)
                    SafetyBadge(safety: finding.spot.safety)
                }
                Text(finding.spot.what)
                    .prose(12)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(finding.spot.after)
                    .prose(12)
                    .foregroundStyle(Palette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Metrics.spacingS)

            VStack(alignment: .trailing, spacing: 6) {
                Text(StorageFormat.gb(finding.bytes))
                    .codeLabel(12)
                    .foregroundStyle(Palette.ink)
                if isClearing {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Clear") { isConfirming = true }
                        .controlSize(.small)
                        .disabled(storage.clearingSpot != nil || storage.phase != .idle)
                }
            }
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("Show in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting(finding.targets.prefix(20).map(\.url))
            }
        }
        .confirmationDialog("Move \(finding.spot.title.lowercased()) to the Trash?", isPresented: $isConfirming, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) {
                Task { await storage.clear(finding) }
            }
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting(finding.targets.prefix(20).map(\.url))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(finding.targets.count) item\(finding.targets.count == 1 ? "" : "s"), \(StorageFormat.gb(finding.bytes)). \(finding.spot.after) You can put \(finding.targets.count == 1 ? "it" : "them") back from Recently cleared.")
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SafetyBadge: View {
    let safety: TempSpot.Safety

    var body: some View {
        let (text, tint): (String, Color) = switch safety {
        case .rebuilt: ("Comes back on its own", Palette.mint)
        case .checkFirst: ("Check first", Palette.Vivid.yellow)
        }
        Text(text)
            .prose(10.5, .medium)
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.12), in: .capsule)
    }
}
