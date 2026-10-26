import SwiftUI

struct MetricHelpLabel: View {
    let title: LocalizedStringKey
    let topic: MetricHelpTopic

    var body: some View {
        HStack(spacing: 4) {
            Text(title).help(LocalizedStringKey(topic.explanationKey))
            MetricHelpButton(topic: topic)
        }
    }
}

struct MetricHelpButton: View {
    let topic: MetricHelpTopic
    @State private var isShowingHelp = false

    private var helpLabel: Text {
        Text("metric_explanation") + Text(verbatim: ": ") + Text(LocalizedStringKey(topic.titleKey))
    }

    var body: some View {
        Button { isShowingHelp.toggle() } label: {
            Image(systemName: "info.circle")
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .accessibilityLabel(helpLabel)
        .accessibilityIdentifier("metric-help-\(topic.titleKey)")
        .help(helpLabel)
        .popover(isPresented: $isShowingHelp, arrowEdge: .trailing) {
            MetricHelpView(topic: topic)
        }
    }
}

struct MetricHelpView: View {
    let topic: MetricHelpTopic
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey(topic.titleKey)).font(.headline)
                Spacer(minLength: 8)
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("metric_explanation_close"))
                .accessibilityIdentifier("metric-help-close")
                .help("metric_explanation_close")
                .keyboardShortcut(.cancelAction)
            }
            Text(LocalizedStringKey(topic.explanationKey))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
    }
}
