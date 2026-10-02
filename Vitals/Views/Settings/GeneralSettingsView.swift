import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("updateInterval") private var updateInterval: Double = 1
    @AppStorage("backgroundUpdateInterval") private var backgroundInterval: Double?
    @AppStorage("processUpdateInterval") private var processInterval: Double = 2
    @AppStorage("temperatureUpdateInterval") private var temperatureInterval: Double = 3
    @EnvironmentObject var langManager: LanguageManager

    var body: some View {
        Form {
            intervalPicker("settings_update_interval", selection: $updateInterval)
            intervalPicker("settings_background_interval", selection: Binding(
                get: { backgroundInterval ?? MonitoringPreferences().backgroundInterval },
                set: { backgroundInterval = $0 }
            ))
            intervalPicker("settings_process_interval", selection: $processInterval)
            intervalPicker("settings_temperature_interval", selection: $temperatureInterval)
            Picker("settings_language", selection: $langManager.appLanguage) {
                Text("English").tag("en")
                Text("Русский").tag("ru")
                Text("Deutsch").tag("de")
            }
            .pickerStyle(.menu)
        }
        .padding(20)
    }

    private func intervalPicker(_ title: LocalizedStringKey, selection: Binding<Double>) -> some View {
        Picker(title, selection: selection) {
            ForEach(MonitoringPreferences.intervals, id: \.self) { value in
                (Text(verbatim: value < 1 ? "0.5" : "\(Int(value))") + Text(verbatim: " ") + Text("unit_sec"))
                    .tag(value)
            }
        }
        .pickerStyle(.menu)
    }
}
