import SwiftUI

struct PanelHeader: View {
    @Environment(AppModel.self) private var model
    @FocusState.Binding var focus: PanelFocus?

    var body: some View {
        @Bindable var model = model

        HStack(spacing: Metrics.spacingS) {
            WindowDragGrip()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Search skills", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($focus, equals: .search)
                .onSubmit(model.ensureSelectionVisible)
                .accessibilityLabel("Search skills")

            if !model.query.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill", action: model.clearQuery)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            }

            PanelPinButton()
            PanelMenu()
        }
        .padding(.horizontal, Metrics.spacingM)
        .frame(height: 38)
    }
}
