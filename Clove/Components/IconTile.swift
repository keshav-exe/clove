import SwiftUI

/// Rounded, tinted square holding an SF Symbol. Used in sidebars and settings rows.
struct IconTile: View {
    let systemImage: String
    var tint: Color = .accentColor
    var size: Double = Metrics.tileIcon

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.55, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient.opacity(0.95), in: .rect(cornerRadius: Metrics.tileRadius))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        IconTile(systemImage: "gearshape", tint: .gray)
        IconTile(systemImage: "lock.shield", tint: .green)
        IconTile(systemImage: "keyboard", tint: .indigo)
    }
    .padding()
}
