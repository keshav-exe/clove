import AppKit
import SwiftUI

/// A small, live picture of the top of the screen, showing one thing the
/// notch does. It plays the motion on a loop (open, hold, close) so you see
/// how it moves, not just how it looks. Used by onboarding and What's New.
struct NotchDemo: View {
    enum Scene: Equatable {
        /// Hover: the Now tab, with an agent at work.
        case peek
        /// Click or the shortcut: searching skills.
        case search
        /// An agent working: ears with its app's icon.
        case working
        /// A turn ends: the moment that says so.
        case done
        /// Menu bar mode: the icon and its panel.
        case menuBar
    }

    let scene: Scene
    var size = CGSize(width: 440, height: 250)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowing = false

    private let notch = CGSize(width: 118, height: 20)

    var body: some View {
        ZStack(alignment: .top) {
            screen
            if scene == .menuBar {
                menuBarScene
            } else {
                island
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Palette.ring, lineWidth: 1)
        }
        .task(id: scene) { await loop() }
        .accessibilityHidden(true)
    }

    /// Shows the scene, holds it, puts it away, and goes again. Reduce Motion
    /// holds it open.
    private func loop() async {
        isShowing = false
        if reduceMotion {
            isShowing = true
            return
        }
        try? await Task.sleep(for: .milliseconds(450))
        while !Task.isCancelled {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { isShowing = true }
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 1)) { isShowing = false }
            try? await Task.sleep(for: .seconds(1.1))
        }
    }

    // MARK: - Screen

    /// A plain desktop with a menu bar: placeholders, not a real screenshot.
    private var screen: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 9, weight: .semibold))
                ForEach([30.0, 22, 26, 18], id: \.self) { width in
                    Capsule().frame(width: width, height: 4)
                }
                Spacer()
                ForEach([12.0, 12, 30], id: \.self) { width in
                    Capsule().frame(width: width, height: 4)
                }
            }
            .foregroundStyle(Palette.inkTertiary.opacity(0.7))
            .padding(.horizontal, 14)
            .frame(height: notch.height)
            .background(Palette.surface.opacity(0.6))

            Palette.surfaceSunken
        }
    }

    // MARK: - Island

    private var islandSize: CGSize {
        guard isShowing else { return CGSize(width: notch.width, height: notch.height) }
        switch scene {
        case .working: return CGSize(width: notch.width + 52 + 12, height: notch.height)
        case .done: return CGSize(width: 260, height: notch.height + 40)
        case .peek: return CGSize(width: 300, height: notch.height + 84)
        case .search: return CGSize(width: 300, height: notch.height + 96)
        case .menuBar: return .zero
        }
    }

    private var isPanel: Bool {
        isShowing && (scene == .peek || scene == .search || scene == .done)
    }

    private var island: some View {
        let shape = NotchShape(topRadius: isShowing ? 7 : 0, bottomRadius: isPanel ? 18 : 8)
        let size = islandSize

        return ZStack(alignment: .top) {
            shape
                .fill(.black)
                .shadow(color: .black.opacity(isPanel ? 0.3 : 0), radius: 14, y: 6)
            if isShowing {
                content
                    .padding(.horizontal, 7)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)).animation(.easeOut(duration: 0.2).delay(0.06)),
                        removal: .opacity.animation(.easeIn(duration: 0.08))
                    ))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(shape)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        switch scene {
        case .working:
            HStack(spacing: 0) {
                DemoIcon(size: 12).frame(width: 26)
                Spacer(minLength: 0)
                Circle().fill(.white.opacity(0.8)).frame(width: 4, height: 4).frame(width: 26)
            }
            .frame(height: notch.height)
        case .done:
            VStack(spacing: 0) {
                Color.clear.frame(height: notch.height)
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Palette.mint)
                        .frame(width: 20, height: 20)
                        .background(Palette.mint.opacity(0.18), in: .circle)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Claude finished in app").font(.system(size: 9.5, weight: .semibold))
                        Text("The hero is fixed.").font(.system(size: 8.5)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Text("Show")
                        .font(.system(size: 8.5, weight: .semibold))
                        .padding(.horizontal, 7)
                        .frame(height: 16)
                        .background(.white.opacity(0.14), in: .capsule)
                }
                .padding(.horizontal, 10)
                .frame(maxHeight: .infinity)
            }
            .foregroundStyle(.white)
        case .peek:
            VStack(alignment: .leading, spacing: 0) {
                strip(title: "Now")
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        DemoIcon(size: 15)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Fix the hero").font(.system(size: 9.5, weight: .semibold))
                            Text("Claude · app · Working").font(.system(size: 8)).foregroundStyle(.secondary)
                        }
                    }
                    DemoStep(text: "Read Notes.md", isDone: true)
                    DemoStep(text: "Edit Hero.swift", isDone: false)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.07), in: .rect(cornerRadius: 9, style: .continuous))
                .padding(.horizontal, 6)
            }
            .foregroundStyle(.white)
        case .search:
            VStack(alignment: .leading, spacing: 0) {
                strip(title: "Skills")
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: "magnifyingglass").font(.system(size: 8, weight: .semibold))
                        Text("rev").font(.system(size: 9.5))
                        Rectangle().frame(width: 1, height: 10)
                        Spacer()
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 6, style: .continuous))
                    ForEach(Array(["review", "review-pr", "ui-review"].enumerated()), id: \.offset) { index, name in
                        Text(name)
                            .font(.system(size: 9.5, weight: .medium))
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
                            .background(index == 0 ? .white.opacity(0.12) : .clear, in: .rect(cornerRadius: 5, style: .continuous))
                    }
                }
                .padding(.horizontal, 6)
            }
            .foregroundStyle(.white)
        case .menuBar:
            EmptyView()
        }
    }

    /// The island's tab strip: a title to the left of the notch, tab dots to its right.
    private func strip(title: String) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            Spacer(minLength: notch.width)
            HStack(spacing: 4) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(.white.opacity(index == (title == "Now" ? 0 : 1) ? 0.85 : 0.3))
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.trailing, 6)
        }
        .frame(height: notch.height)
    }

    // MARK: - Menu bar

    private var menuBarScene: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Color.clear.frame(height: notch.height)
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 22, height: 16)
                    .background(isShowing ? Palette.ink.opacity(0.12) : .clear, in: .rect(cornerRadius: 4, style: .continuous))
                    .padding(.top, 2)
                    .padding(.trailing, 70)
            }
            // The notch stays clear for another app.
            .overlay(alignment: .top) {
                NotchShape(topRadius: 0, bottomRadius: 8)
                    .fill(.black)
                    .frame(width: notch.width, height: notch.height)
            }
            HStack {
                Spacer()
                if isShowing {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Skills").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(Palette.ink)
                        ForEach(["review", "swiftui-pro", "animations"], id: \.self) { name in
                            Text(name)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                    .padding(10)
                    .frame(width: 150, alignment: .leading)
                    .background(Palette.surface, in: .rect(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Palette.ring, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            }
            .padding(.trailing, 14)
            .padding(.top, 6)
        }
    }
}

/// The icon an agent's card shows: Claude's, when it's installed.
private struct DemoIcon: View {
    let size: CGFloat

    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.anthropic.claudefordesktop") {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "terminal.fill")
                .font(.system(size: size * 0.7))
                .frame(width: size, height: size)
        }
    }
}

private struct DemoStep: View {
    let text: String
    let isDone: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: isDone ? "checkmark" : "play.fill")
                .font(.system(size: 6.5, weight: .bold))
                .foregroundStyle(isDone ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                .frame(width: 9)
            Text(text)
                .font(.system(size: 9, weight: isDone ? .regular : .medium))
                .foregroundStyle(isDone ? .secondary : .primary)
        }
    }
}
