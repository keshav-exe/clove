import SwiftUI

/// What's filling this Mac: the instrument, then the biggest things on the
/// disk. Pick a part of the bar or legend and the list narrows to it.
struct StoragePage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let storage = model.storage
        let rows = storage.largest()

        OverviewPage {
            PageHeader(title: "Storage", summary: summary)

            StorageCard(store: storage, pinned: storage.pinned) { kind in
                withAnimation(.easeOut(duration: 0.2)) {
                    storage.pinned = storage.pinned == kind ? nil : kind
                }
            }

            Tile {
                TileHeader(
                    title: storage.pinned.map { "Largest in \($0.title)" } ?? "Largest on this Mac",
                    note: storage.hasScanned ? rows.count.formatted() : nil
                ) {
                    if storage.pinned != nil {
                        Button("Show All") {
                            withAnimation(.easeOut(duration: 0.2)) { storage.pinned = nil }
                        }
                        .buttonStyle(.link)
                        .prose(12)
                    }
                }
            } content: {
                if rows.isEmpty {
                    Text(emptyLine)
                        .prose(13)
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(maxWidth: .infinity, minHeight: 64)
                } else {
                    VStack(spacing: 0) {
                        ForEach(rows) { item in
                            StorageRow(item: item)
                        }
                    }
                }
            }
        }
        .navigationTitle("Storage")
        .alert(
            "Something didn't go",
            isPresented: Binding { storage.failure != nil } set: { if !$0 { storage.failure = nil } },
            presenting: storage.failure
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text(failure)
        }
        .confirmationDialog(
            storage.pendingTrash.map { "Move “\($0.name)” to the Trash?" } ?? "",
            isPresented: Binding { storage.pendingTrash != nil } set: { if !$0 { storage.pendingTrash = nil } },
            titleVisibility: .visible,
            presenting: storage.pendingTrash
        ) { item in
            Button("Move to Trash", role: .destructive) {
                storage.moveToTrash(item)
                storage.pendingTrash = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("It takes \(StorageFormat.gb(item.bytes)) at \(StorageFormat.path(item.url)). You can put it back from the Trash.")
        }
        .task {
            await storage.scanIfNeeded()
        }
    }

    private var summary: String {
        let storage = model.storage
        guard let volume = storage.volume else { return "What's filling this Mac, and what's safe to clear." }
        return "\(StorageFormat.gb(volume.available)) free of \(StorageFormat.capacity(volume.capacity)). Hover the bar to see what's in each part, click one to list it."
    }

    private var emptyLine: String {
        let storage = model.storage
        if storage.phase == .scanning { return "Measuring…" }
        if let kind = storage.pinned { return "Nothing in \(kind.title.lowercased()) is over 50 MB." }
        return "Rescan to measure."
    }
}

/// One big thing: what it is, where it lives, how much it takes. Hovering
/// shows its two actions.
private struct StorageRow: View {
    @Environment(AppModel.self) private var model
    let item: StorageItem
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Metrics.spacingM) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path(percentEncoded: false)))
                .resizable()
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .prose(13, .medium)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(StorageFormat.path(item.url.deletingLastPathComponent()))
                    .prose(11)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: Metrics.spacingS)

            HStack(spacing: 2) {
                Button("Show in Finder", systemImage: "folder") { model.storage.reveal(item) }
                if item.canMoveToTrash {
                    Button("Move to Trash", systemImage: "trash") { model.storage.pendingTrash = item }
                        .disabled(model.storage.isBusy)
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .opacity(isHovered ? 1 : 0)

            HStack(spacing: 6) {
                StorageGlyph(symbol: item.kind.symbol, size: 14)
                    .foregroundStyle(item.kind.paperTint)
                Text(StorageFormat.gb(item.bytes))
                    .monoLabel(12)
                    .foregroundStyle(Palette.ink)
                    .frame(minWidth: 64, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.hairline).frame(height: 0.5)
        }
        .contextMenu {
            Button("Show in Finder", systemImage: "folder") { model.storage.reveal(item) }
            if item.canMoveToTrash {
                Divider()
                Button("Move to Trash", systemImage: "trash", role: .destructive) { model.storage.pendingTrash = item }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(StorageFormat.gb(item.bytes)), \(item.kind.title)")
    }
}
