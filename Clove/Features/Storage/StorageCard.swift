import SwiftUI

/// A storage page where the disk is a strip of dithered light. Each kind of
/// file is a run of cells in its own colour, and the empty end is a dark grid.
/// Rest on a part to see what's in it. Rescan and the bar drains and counts
/// itself back up as the scan walks the disk, its front running hot. Clear the
/// caches or empty the Trash and those cells come loose and rise off the bar,
/// and the space they held goes dark.
///
/// It follows the theme: graphite with white-hot cells in the dark, white
/// paper with deeper hues and cells that run dark-hot in the light.
struct StorageCard: View {
    let store: StorageStore
    /// The part picked on the legend, which stays lit when nothing is hovered.
    var pinned: StorageKind?
    var pick: (StorageKind) -> Void = { _ in }
    /// Panel width: the same bar, a legend of icons and sizes, no dialog.
    var isCompact = false
    /// In compact mode the clear happens in the main window, where it's confirmed.
    var openClear: (StorageClean) -> Void = { _ in }

    @State private var readout = StorageReadout()
    @State private var hover: StorageKind?
    @State private var highlight: StorageKind = .apps
    @State private var showsHighlight = false
    @State private var barWidth: CGFloat = 1

    private var gutter: CGFloat { isCompact ? 16 : 24 }
    private var legendRow: CGFloat { isCompact ? 26 : 30 }
    private var footerHeight: CGFloat { isCompact ? 50 : 62 }
    private var radius: CGFloat { isCompact ? 16 : 20 }
    /// White on paper, graphite in the dark: the web system's panel and chrome.
    /// White on paper; in the dark, a step above the page so the card reads as raised.
    private static let surface = Color.oklch(light: (1, 0, 0), dark: (0.27, 0.004, 265))
    private static let edgeLight = Color.dynamic(light: 0xFFFFFF, dark: 0xFFFFFF, lightOpacity: 0, darkOpacity: 0.09)
    private static let seamShade = Color.dynamic(light: 0xE6E6E8, dark: 0x000000, lightOpacity: 1, darkOpacity: 0.45)
    private static let seamLight = Color.dynamic(light: 0xFFFFFF, dark: 0xFFFFFF, lightOpacity: 0, darkOpacity: 0.05)
    private static let dropShadow = Color.dynamic(light: 0x000000, dark: 0x000000, lightOpacity: 0.06, darkOpacity: 0.3)

    /// What's being looked at: the pointer wins, then the selection. Nothing while busy.
    private var looking: StorageKind? {
        guard store.phase == .idle else { return nil }
        return hover ?? pinned
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .frame(height: 28)
                status
                    .frame(height: 18)
                    .padding(.top, 8)
                barSlot
                    .padding(.top, 22)
                legend
                    .padding(.top, 20)
                    .padding(.horizontal, -8)
            }
            .padding(.horizontal, gutter)
            .padding(.top, isCompact ? 14 : 22)
            .padding(.bottom, isCompact ? 12 : 16)
            .backgroundPreferenceValue(BarBoundsKey.self) { anchor in
                GeometryReader { proxy in
                    if let anchor {
                        let rect = proxy[anchor]
                        let margin = StorageBarRenderer.margin
                        StorageBarView(store: store, readout: readout, hover: looking?.rawValue ?? -1)
                            .frame(width: rect.width + margin.side * 2, height: rect.height + margin.top + margin.bottom)
                            .offset(x: rect.minX - margin.side, y: rect.minY - margin.top)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
            }

            seam
            footer
                .frame(height: footerHeight)
                .padding(.horizontal, gutter)
        }
        .prose(13)
        .foregroundStyle(Palette.ink)
        // A faint ring, and in the dark a hairline of light along the top edge.
        .background(Self.surface, in: .rect(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Palette.ring, lineWidth: 1)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Self.edgeLight)
                .frame(height: 1)
                .padding(.horizontal, 20)
        }
        .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
        .shadow(color: Self.dropShadow, radius: 16, y: 10)
        .onChange(of: looking) { _, kind in
            moveHighlight(to: kind)
        }
        .confirmationDialog(
            isCompact ? "" : confirmTitle,
            isPresented: isCompact ? .constant(false) : confirmBinding,
            titleVisibility: .visible,
            presenting: store.pendingClean
        ) { clean in
            Button(clean.verb, role: .destructive) {
                Task { await store.clear(clean) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { clean in
            Text(confirmMessage(clean))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(readout.used.isEmpty ? StorageFormat.gb(store.used) : readout.used)
                    .font(.system(size: isCompact ? 20 : 24, weight: .medium).monospacedDigit())
                    .tracking(-0.4)
                    .contentTransition(.identity)
                Text(isCompact ? "of \(StorageFormat.capacity(store.capacity))" : "of \(StorageFormat.capacity(store.capacity)) used")
                    .prose(14, .medium)
                    .foregroundStyle(Palette.inkSecondary)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 12)

            Button(action: store.rescan) {
                HStack(spacing: 6) {
                    StorageGlyph(symbol: "arrow.clockwise", size: 16)
                        .spinning(store.phase == .scanning)
                    if !isCompact { Text("Rescan") }
                }
            }
            .buttonStyle(StorageQuietButtonStyle())
            .disabled(store.isBusy)
            .padding(.trailing, -8)
            .help("Measure the disk again")
            .accessibilityLabel("Rescan")
        }
    }

    // MARK: - Status line

    @ViewBuilder
    private var status: some View {
        Group {
            switch store.phase {
            case .scanning, .cleaning:
                HStack(spacing: 8) {
                    Text(busyTitle)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.primary.opacity(0.8))
                    Text(store.currentPath ?? "")
                        .codeLabel(11.5)
                        .foregroundStyle(Color.primary.opacity(0.4))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .id("busy")
            case .idle:
                if let kind = looking {
                    HStack(spacing: 6) {
                        StorageGlyph(symbol: kind.symbol, size: 16)
                            .foregroundStyle(kind.paperTint)
                        Text(kind.title)
                            .fontWeight(.medium)
                        Text(StorageFormat.gb(store.bytes(of: kind)))
                            .monospacedDigit()
                            .foregroundStyle(Color.primary.opacity(0.5))
                        Text(store.note(for: kind))
                            .foregroundStyle(Color.primary.opacity(0.5))
                            .lineLimit(1)
                            .padding(.leading, 4)
                    }
                    .id(kind)
                } else if let freed = store.freed {
                    HStack(spacing: 6) {
                        StorageGlyph(symbol: "checkmark.circle.fill", size: 16)
                            .foregroundStyle(Palette.mint)
                        if let id = freed.record, let record = store.history.first(where: { $0.id == id }) {
                            // Recoverable: say where it went and offer it back, right here.
                            Text("Moved \(StorageFormat.gb(freed.bytes)) to the Trash.")
                                .fontWeight(.medium)
                            Button("Put Back") {
                                Task { await store.putBack(record) }
                            }
                            .buttonStyle(.link)
                            .fontWeight(.medium)
                        } else {
                            Text("Freed \(StorageFormat.gb(freed.bytes)).")
                                .fontWeight(.medium)
                            Text("\(StorageFormat.gb(store.available)) available")
                                .monospacedDigit()
                                .foregroundStyle(Color.primary.opacity(0.5))
                        }
                    }
                    .id("freed")
                } else {
                    Text("\(StorageFormat.gb(store.available)) available")
                        .monospacedDigit()
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .id("free")
                }
            }
        }
        .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 2)), removal: .identity))
        .animation(.easeOut(duration: 0.18), value: statusKey)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private var statusKey: String {
        switch store.phase {
        case .scanning, .cleaning: "busy"
        case .idle: looking.map { "\($0.rawValue)" } ?? (store.freed == nil ? "free" : "freed")
        }
    }

    private var busyTitle: String {
        if case .cleaning(let clean) = store.phase { return clean.doing }
        return "Calculating"
    }

    // MARK: - Bar

    private var barSlot: some View {
        Color.clear
            .frame(height: StorageBarRenderer.height)
            .frame(maxWidth: .infinity)
            .anchorPreference(key: BarBoundsKey.self, value: .bounds) { $0 }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { barWidth = $0 }
            .contentShape(.rect)
            .onTapGesture {
                if let hover { pick(hover) }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    look(at: point.x)
                case .ended:
                    look(nil)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Disk usage")
            .accessibilityValue("\(StorageFormat.gb(store.used)) of \(StorageFormat.capacity(store.capacity)) used")
    }

    /// The bar's width stands for the whole disk, so a point along it falls in one kind.
    private func look(at x: CGFloat) {
        let width = max(1, barWidth)
        let position = Double(x / width) * Double(store.capacity)
        var total: Double = 0
        var found: StorageKind?
        for kind in StorageKind.allCases {
            total += Double(store.bytes(of: kind))
            if position < total {
                found = kind
                break
            }
        }
        if found != hover { look(found) }
    }

    private func look(_ kind: StorageKind?) {
        guard store.phase == .idle || kind == nil else { return }
        hover = kind
    }

    // MARK: - Legend

    private var legend: some View {
        let kinds = StorageKind.allCases
        let columns = 3
        return GeometryReader { proxy in
            let itemWidth = proxy.size.width / CGFloat(columns)
            ZStack(alignment: .topLeading) {
                // One highlight that slides between items.
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.045), lineWidth: 0.5)
                    }
                    .shadow(color: Self.dropShadow, radius: 2, y: 1)
                    .frame(width: itemWidth - 4, height: legendRow - 2)
                    .offset(
                        x: CGFloat(highlight.rawValue % columns) * itemWidth + 2,
                        y: CGFloat(highlight.rawValue / columns) * legendRow + 1
                    )
                    .opacity(showsHighlight ? 1 : 0)

                ForEach(kinds) { kind in
                    legendItem(kind)
                        .frame(width: itemWidth, height: legendRow)
                        .offset(
                            x: CGFloat(kind.rawValue % columns) * itemWidth,
                            y: CGFloat(kind.rawValue / columns) * legendRow
                        )
                }
            }
        }
        .frame(height: legendRow * CGFloat((kinds.count + columns - 1) / columns))
        .onHover { inside in
            if !inside { look(nil) }
        }
    }

    private func legendItem(_ kind: StorageKind) -> some View {
        let isLooking = looking == kind
        let isDimmed = looking != nil && !isLooking
        return HStack(spacing: 8) {
            StorageGlyph(symbol: kind.symbol, size: isCompact ? 14 : 16)
                .foregroundStyle(kind.paperTint)
            if !isCompact {
                Text(kind.title)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary.opacity(isLooking ? 1 : 0.88))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(readout.sizes[kind.rawValue].isEmpty ? StorageFormat.gb(store.bytes(of: kind)) : readout.sizes[kind.rawValue])
                .monoLabel(isCompact ? 11 : 12)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(Color.primary.opacity(isCompact ? 0.7 : 0.5))
                .padding(.trailing, isCompact ? 2 : 4)
        }
        .padding(.horizontal, isCompact ? 8 : 10)
        .opacity(isDimmed ? 0.6 : 1)
        .animation(.easeOut(duration: 0.15), value: isDimmed)
        .contentShape(.rect)
        .onHover { inside in
            if inside { look(kind) }
        }
        .onTapGesture { pick(kind) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(pinned == kind ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { pick(kind) }
        .accessibilityLabel("\(kind.title), \(StorageFormat.gb(store.bytes(of: kind)))")
        .accessibilityHint(store.note(for: kind))
    }

    private func moveHighlight(to kind: StorageKind?) {
        guard let kind else {
            withAnimation(.interpolatingSpring(stiffness: 420, damping: 41)) { showsHighlight = false }
            return
        }
        if showsHighlight {
            withAnimation(.interpolatingSpring(stiffness: 420, damping: 41)) { highlight = kind }
        } else {
            // From nothing, it appears where you are rather than sliding in from the last spot.
            highlight = kind
            withAnimation(.interpolatingSpring(stiffness: 420, damping: 41)) { showsHighlight = true }
        }
    }

    // MARK: - Seam and footer

    /// Engraved: a dark line with a faint lit one under it.
    private var seam: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Self.seamShade).frame(height: 1)
            Rectangle().fill(Self.seamLight).frame(height: 1)
        }
        .padding(.horizontal, 1)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 8) {
            if store.phase == .scanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(isCompact ? "Looking for what to clear" : "Looking for things you can clear")
                }
                .foregroundStyle(Color.primary.opacity(0.5))
                .id("look")
            } else if let clean = store.recommendation ?? activeClean {
                HStack(spacing: 8) {
                    StorageGlyph(symbol: clean.kind.symbol, size: 16)
                        .foregroundStyle(clean.kind.paperTint)
                    // The amount this button will actually clear, the same number Home quotes.
                    let size = StorageFormat.gb(clean == .caches ? store.clearableBytes(for: .caches) : store.bytes(of: clean.kind))
                    Text(isCompact ? clean.shortLine(size) : clean.line(size))
                        .foregroundStyle(Color.primary.opacity(0.88))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .id(clean)
                Spacer(minLength: 12)
                Button(clean.verb) {
                    if isCompact {
                        openClear(clean)
                    } else {
                        store.pendingClean = clean
                    }
                }
                .buttonStyle(StorageFilledButtonStyle())
                .disabled(store.isBusy)
                .onHover { inside in look(inside ? clean.kind : nil) }
                .padding(.trailing, -4)
            } else if store.hasScanned, store.reports[.trash]?.isRestricted == true {
                HStack(spacing: 8) {
                    StorageGlyph(symbol: "trash.fill", size: 16)
                        .foregroundStyle(Palette.Vivid.red)
                    Text(isCompact ? "Trash needs access" : "Give Clove Full Disk Access to see what's in the Trash.")
                        .foregroundStyle(Color.primary.opacity(0.88))
                        .lineLimit(1)
                }
                .id("access")
                Spacer(minLength: 12)
                Button(isCompact ? "Allow…" : "Open Settings…", action: StorageStore.openFullDiskAccessSettings)
                    .buttonStyle(StorageFilledButtonStyle())
                    .padding(.trailing, -4)
            } else if store.hasScanned {
                HStack(spacing: 8) {
                    StorageGlyph(symbol: "checkmark.circle.fill", size: 16)
                        .foregroundStyle(Palette.mint)
                    Text(isCompact ? "Nothing worth clearing." : "Nothing else is worth clearing right now.")
                        .foregroundStyle(Color.primary.opacity(0.88))
                }
                .id("none")
            } else {
                Text("Rescan to see what you can clear.")
                    .foregroundStyle(Color.primary.opacity(0.5))
                    .id("idle")
            }
        }
        .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 2)), removal: .identity))
        .animation(.easeOut(duration: 0.18), value: footerKey)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// While a clear runs, its line and button stay up, disabled.
    private var activeClean: StorageClean? {
        if case .cleaning(let clean) = store.phase { return clean }
        return nil
    }

    private var footerKey: String {
        if store.phase == .scanning { return "look" }
        if let clean = store.recommendation ?? activeClean { return clean.verb }
        return store.hasScanned ? "none" : "idle"
    }

    // MARK: - Confirming

    private var confirmBinding: Binding<Bool> {
        Binding {
            store.pendingClean != nil
        } set: { isShowing in
            if !isShowing { store.pendingClean = nil }
        }
    }

    private var confirmTitle: String {
        switch store.pendingClean {
        case .caches: store.trashFirst
            ? "Move \(StorageFormat.gb(store.clearableBytes(for: .caches))) of caches to the Trash?"
            : "Delete \(StorageFormat.gb(store.clearableBytes(for: .caches))) of caches?"
        case .trash: "Empty the Trash?"
        case nil: ""
        }
    }

    private func confirmMessage(_ clean: StorageClean) -> String {
        switch clean {
        case .caches:
            store.trashFirst
                ? "They go to the Trash first, so you can put them back from here until you empty it. Caches for open apps, for macOS, and folders you keep are left alone."
                : "They're deleted straight away. Apps rebuild them when they need them. Caches for open apps, for macOS, and folders you keep are left alone."
        case .trash:
            "\(StorageFormat.gb(store.bytes(of: .trash))) will be erased for good. You can't undo this."
        }
    }
}

private struct BarBoundsKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

// MARK: - Pieces

/// A kind's SF Symbol, two-tone the way macOS draws them.
struct StorageGlyph: View {
    let symbol: String
    var size: CGFloat = 16

    var body: some View {
        Image(systemName: symbol)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: size * 0.82, weight: .medium))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct Spinning: ViewModifier {
    let isActive: Bool
    @State private var angle: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onAppear(perform: update)
            .onChange(of: isActive) { update() }
    }

    private func update() {
        if isActive, !reduceMotion {
            angle = 0
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { angle = 360 }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { angle = 0 }
        }
    }
}

extension View {
    func spinning(_ isActive: Bool) -> some View {
        modifier(Spinning(isActive: isActive))
    }
}

/// Rescan: text only until you rest on it.
private struct StorageQuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .prose(13, .medium)
            .foregroundStyle(Color.primary.opacity(isEnabled ? (isHovered ? 1 : 0.65) : 0.35))
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(Color.primary.opacity(isEnabled && isHovered ? 0.08 : 0), in: .rect(cornerRadius: 8, style: .continuous))
            .contentShape(.rect)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

/// The one thing worth doing.
private struct StorageFilledButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .prose(13, .medium)
            .lineLimit(1)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Color.primary.opacity(isHovered && isEnabled ? 0.13 : 0.08), in: .rect(cornerRadius: 8, style: .continuous))
            .contentShape(.rect)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}
