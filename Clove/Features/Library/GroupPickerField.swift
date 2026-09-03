import SwiftUI

/// Single field for adding a skill to a group: type to create, or pick a suggestion.
struct GroupPickerField: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    let skill: Skill

    @State private var draft = ""
    @State private var highlightedIndex = 0
    @State private var isPresented = false
    @State private var ignoreHoverUntil: Date = .distantPast
    @State private var dismissTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    private var assigned: [String] {
        model.tags(for: skill)
    }

    private var suggestions: [GroupSuggestion] {
        GroupSuggestion.matching(
            query: draft,
            assigned: assigned,
            available: model.allGroups
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            field

            if isPresented {
                menu
            }
        }
        .zIndex(isPresented ? 1 : 0)
        .onChange(of: isFocused) { _, focused in
            handleFocusChange(focused)
        }
        .onChange(of: draft) {
            highlightedIndex = 0
        }
        .onChange(of: skill.id) {
            reset(dismissing: true)
        }
        .onDisappear {
            dismissTask?.cancel()
        }
    }

    private var field: some View {
        HStack(spacing: 6) {
            TextField("Add to a group", text: $draft)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit(submit)
                .onKeyPress(.downArrow, action: moveDown)
                .onKeyPress(.upArrow, action: moveUp)
                .onKeyPress(.escape, action: dismiss)

            Button("Show groups", systemImage: "chevron.up.chevron.down", action: toggleMenu)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .focusable(false)
        }
        .font(.body)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.fill.quaternary, in: .rect(cornerRadius: Metrics.controlRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.controlRadius)
                .strokeBorder(Color.primary.opacity(isFocused ? 0.16 : 0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Add to a group")
        .accessibilityHint("Type a name to create a group, or choose an existing one.")
    }

    private var menu: some View {
        Group {
            if suggestions.count > 6 {
                ScrollViewReader { proxy in
                    ScrollView {
                        rows
                    }
                    .frame(height: Metrics.suggestionMenuMaxHeight)
                    .scrollIndicators(.hidden)
                    .onChange(of: highlightedIndex) { _, newValue in
                        scrollToHighlight(proxy, index: newValue)
                    }
                }
            } else {
                rows
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: Metrics.controlRadius)
                .fill(menuFill)
                .shadow(color: menuShadow, radius: 10, y: 4)
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.controlRadius)
                        .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Group suggestions")
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 1) {
            if suggestions.isEmpty {
                Text(emptyCopy)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(suggestions.enumerated(), id: \.element.id) { index, suggestion in
                    Button {
                        choose(suggestion)
                    } label: {
                        GroupSuggestionRow(
                            suggestion: suggestion,
                            isHighlighted: index == highlightedIndex
                        )
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .id(suggestion.id)
                    .onHover { hovering in
                        guard hovering, Date.now >= ignoreHoverUntil else { return }
                        highlightedIndex = index
                    }
                }
            }
        }
    }

    private var emptyCopy: String {
        let query = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? "No other groups yet." : "Already in this group."
    }

    private var menuFill: Color {
        colorScheme == .dark ? Color.primary.opacity(0.08) : Color.white
    }

    private var menuShadow: Color {
        colorScheme == .dark ? .clear : Color.black.opacity(0.1)
    }

    private func submit() {
        if suggestions.indices.contains(highlightedIndex) {
            choose(suggestions[highlightedIndex])
            return
        }
        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        add(name)
    }

    private func choose(_ suggestion: GroupSuggestion) {
        add(suggestion.name)
    }

    private func add(_ name: String) {
        dismissTask?.cancel()
        model.addSkillToGroup(skill, group: name)
        reset(dismissing: true)
    }

    private func reset(dismissing: Bool) {
        draft = ""
        highlightedIndex = 0
        if dismissing {
            isPresented = false
            isFocused = false
        }
    }

    private func moveDown() -> KeyPress.Result {
        guard !suggestions.isEmpty else { return .ignored }
        isPresented = true
        ignoreHoverUntil = Date.now.addingTimeInterval(0.35)
        highlightedIndex = min(highlightedIndex + 1, suggestions.count - 1)
        return .handled
    }

    private func moveUp() -> KeyPress.Result {
        guard !suggestions.isEmpty else { return .ignored }
        isPresented = true
        ignoreHoverUntil = Date.now.addingTimeInterval(0.35)
        highlightedIndex = max(highlightedIndex - 1, 0)
        return .handled
    }

    private func toggleMenu() {
        if isPresented {
            dismissNow()
        } else {
            isFocused = true
            isPresented = true
        }
    }

    private func dismiss() -> KeyPress.Result {
        guard isPresented || isFocused else { return .ignored }
        dismissNow()
        return .handled
    }

    private func handleFocusChange(_ focused: Bool) {
        dismissTask?.cancel()
        if focused {
            isPresented = true
            return
        }

        // Keep the menu mounted through mouse-up so a click on a row still lands.
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled, !isFocused else { return }
            isPresented = false
        }
    }

    private func dismissNow() {
        dismissTask?.cancel()
        isPresented = false
        isFocused = false
    }

    private func scrollToHighlight(_ proxy: ScrollViewProxy, index: Int) {
        guard suggestions.indices.contains(index) else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(suggestions[index].id)
        }
    }
}
