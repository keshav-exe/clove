import SwiftUI

struct PanelFooter: View {
    @Environment(AppModel.self) private var model
    @FocusState.Binding var focus: PanelFocus?

    private var canTag: Bool {
        model.selectedSkill != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            if canTag {
                tagRow

                Divider()
                    .opacity(0.6)
            }

            PanelShortcutHints()
        }
    }

    private var tagRow: some View {
        @Bindable var model = model

        return HStack(spacing: Metrics.spacingS) {
            Image(systemName: "tag")
                .font(.system(size: 10))
                .foregroundStyle(focus == .footer ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .accessibilityHidden(true)

            TextField("Add a tag", text: $model.footerText)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .focused($focus, equals: .footer)
                .onSubmit(model.addFooterTag)
                .accessibilityLabel("Add a tag to the selected skill")

            Spacer(minLength: Metrics.spacingS)

            if focus != .footer {
                Text("⇥")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 4, style: .continuous))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Metrics.spacingM)
        .frame(height: 30)
    }
}
