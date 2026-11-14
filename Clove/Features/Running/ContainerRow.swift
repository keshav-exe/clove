import SwiftUI

/// One container: what it is, whether it's up, and the controls to change that.
/// The controls sit on the row because there's nothing more to read in an inspector.
struct ContainerRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let container: Container

    var body: some View {
        let store = model.containers
        let isBusy = store.busy.contains(container.id)

        HStack(spacing: Metrics.spacingM) {
            Circle()
                .fill(container.state.isRunning ? Palette.mint : Palette.inkTertiary)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Metrics.spacingXS) {
                    Text(container.name)
                        .prose(13, .medium)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    if !container.ports.isEmpty {
                        Text(container.ports.map { ":\($0)" }.joined(separator: " "))
                            .codeLabel(11)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
                Text("\(container.image) · \(container.status)")
                    .prose(11)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: Metrics.spacingS)

            if isBusy {
                ProgressView()
                    .controlSize(.small)
            } else {
                HStack(spacing: 2) {
                    if let url = container.localURL, container.state.isRunning {
                        Button("Open in Browser", systemImage: "safari") { openURL(url) }
                            .help("Open \(url.absoluteString)")
                    }
                    if container.state.isRunning {
                        Button("Restart", systemImage: "arrow.clockwise") {
                            Task { await store.restart(container) }
                        }
                        .help("Restart \(container.name)")
                        Button("Stop", systemImage: "stop.circle") {
                            Task { await store.stop(container) }
                        }
                        .help("Stop \(container.name)")
                    } else {
                        Button("Start", systemImage: "play.circle") {
                            Task { await store.start(container) }
                        }
                        .help("Start \(container.name)")
                    }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(container.name), \(container.state.title)")
    }
}

/// Containers on the Running page: running first, then stopped, or a plain
/// line about why there are none.
struct ContainersSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let store = model.containers
        switch store.availability {
        case .unknown, .notInstalled:
            // No Docker on this Mac: nothing to show, and nothing to nag about.
            EmptyView()
        case .notRunning:
            ListSection(title: "Containers") {
                Text("Docker isn't running. Start Docker Desktop, OrbStack, or Colima to see your containers here.")
                    .prose(12)
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(12)
            }
        case .ready:
            if !store.containers.isEmpty {
                ListSection(
                    title: "Containers",
                    note: store.running.count == store.containers.count
                        ? store.containers.count.formatted()
                        : "\(store.running.count) of \(store.containers.count) running"
                ) {
                    DividedRows {
                        ForEach(store.containers) { container in
                            ContainerRow(container: container)
                        }
                    }
                }
            }
        }
    }
}
