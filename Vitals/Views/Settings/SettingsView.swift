import SwiftUI

struct SettingsView: View {
    enum Section: String, CaseIterable, Identifiable {
        case general, thresholds, appearance, menubar
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .general: "settings_tab_general"
            case .thresholds: "settings_tab_thresholds"
            case .appearance: "settings_tab_appearance"
            case .menubar: "settings_tab_menubar"
            }
        }
        var icon: String {
            switch self {
            case .general: "gearshape"
            case .thresholds: "chart.bar"
            case .appearance: "paintbrush"
            case .menubar: "menubar.rectangle"
            }
        }
    }

    @State private var selection: Section = .general
    private let appearanceTab: Int

    init(initialSection: Section = .general, appearanceTab: Int = 0) {
        _selection = State(initialValue: initialSection)
        self.appearanceTab = appearanceTab
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Vitals").font(.title2.bold()).padding(.horizontal, 12)
                VStack(spacing: 4) {
                    ForEach(Section.allCases) { section in
                        Button {
                            selection = section
                        } label: {
                            Label(section.title, systemImage: section.icon)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .foregroundStyle(selection == section ? Color.blue : Color.primary)
                                .background(selection == section ? Color.blue.opacity(0.15) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                Spacer()
            }
            .padding(.top, 24)
            .frame(width: 190)
            .background(.background.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 16) {
                Text(selection.title).font(.title2.bold()).padding(.horizontal, 24)
                switch selection {
                case .general: GeneralSettingsView()
                case .thresholds: ThresholdsSettingsView()
                case .appearance: AppearanceSettingsView(initialTab: appearanceTab)
                case .menubar: MenuBarSettingsView()
                }
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 720, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    SettingsView().environmentObject(LanguageManager())
}
