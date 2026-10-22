import SwiftUI

struct ResourceDetailGrid: View {
    let resource: AgentResource
    let usage: String?

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Metrics.spacingL, verticalSpacing: Metrics.spacingS) {
            ForEach(resource.details, id: \.self) { detail in
                GridRow {
                    Text(detail.label)
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    Text(detail.value)
                        .font(detail.isCode ? .callout.monospaced() : .callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let tokens = resource.tokens {
                GridRow {
                    Text("Context")
                        .foregroundStyle(.secondary)
                    Text(contextLine(tokens))
                        .monospacedDigit()
                }
            }
            if let usage {
                GridRow {
                    Text("Usage")
                        .foregroundStyle(.secondary)
                    Text(usage)
                }
            }
        }
        .font(.callout)
    }

    private func contextLine(_ tokens: Int) -> String {
        let amount = tokens.formatted()
        return resource.kind == .instructions
            ? "About \(amount) tokens, loaded into every session"
            : "About \(amount) tokens listed in every session"
    }
}
