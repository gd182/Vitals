import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var langManager: LanguageManager
    @AppStorage("backgroundUpdateInterval") private var backgroundInterval: Double?
    let complete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Vitals").font(.largeTitle.bold())
                    Text("setup_title").font(.headline).foregroundStyle(.secondary)
                }
            }
            .padding(24)
            Form {
                Section {
                    Picker("settings_language", selection: $langManager.appLanguage) {
                        Text("English").tag("en")
                        Text("Русский").tag("ru")
                        Text("Deutsch").tag("de")
                    }
                }
                Section {
                    Picker("settings_background_interval", selection: Binding(
                        get: { backgroundInterval ?? MonitoringPreferences().backgroundInterval },
                        set: { backgroundInterval = $0 }
                    )) {
                        ForEach(MonitoringPreferences.intervals, id: \.self) { value in
                            (Text(verbatim: value < 1 ? "0.5" : "\(Int(value))") + Text(verbatim: " ") + Text("unit_sec"))
                                .tag(value)
                        }
                    }
                }
                MenuBarModuleControls()
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("setup_done", action: complete)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 600, height: 540)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
