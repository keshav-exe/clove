import AppKit
import SwiftUI

/// Apple-style welcome / what's new sheet used for onboarding and release notes.
struct FeatureSheet<Content: View>: View {
    var useAppIcon = false
    var symbolName: String?
    let title: String
    let subtitle: String
    var pageIndex: Int?
    var pageCount: Int?
    var continueTitle = "Continue"
    var showsBack = false
    var onBack: () -> Void = {}
    let onContinue: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                emblem
                    .padding(.top, 28)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 40)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 40)
                .padding(.top, 22)
                .padding(.bottom, 12)

            footer
        }
        .frame(width: FeatureSheetMetrics.width, height: FeatureSheetMetrics.height)
        .background(.background)
    }

    @ViewBuilder
    private var emblem: some View {
        if useAppIcon {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 88, height: 88)
        } else if let symbolName {
            Image(systemName: symbolName)
                .font(.system(size: 42, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
                .frame(width: 72, height: 72)
        }
    }

    private var footer: some View {
        ZStack {
            if let pageIndex, let pageCount {
                FeatureSheetPageIndicator(index: pageIndex, count: pageCount)
            }

            HStack {
                if showsBack {
                    Button("Back", action: onBack)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(continueTitle, action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }
}

private enum FeatureSheetMetrics {
    static let width: Double = 520
    static let height: Double = 580
}

private struct FeatureSheetPageIndicator: View {
    let index: Int
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { item in
                Circle()
                    .fill(item == index ? Color.primary.opacity(0.55) : Color.primary.opacity(0.18))
                    .frame(width: 6, height: 6)
            }
        }
        .animation(.easeOut(duration: 0.2), value: index)
        .accessibilityElement()
        .accessibilityLabel("Page \(index + 1) of \(count)")
    }
}
