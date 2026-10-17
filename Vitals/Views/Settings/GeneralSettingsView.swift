import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @AppStorage("updateInterval") private var updateInterval: Double = 1
    @AppStorage("backgroundUpdateInterval") private var backgroundInterval: Double?
    @AppStorage("processUpdateInterval") private var processInterval: Double = 2
    @AppStorage("temperatureUpdateInterval") private var temperatureInterval: Double = 3
    @AppStorage("includePrereleaseUpdates") private var includePrereleaseUpdates = false
    @AppStorage("automaticUpdateChecks")
    private var automaticUpdateChecks = false
    @EnvironmentObject var langManager: LanguageManager
    @StateObject private var loginItem = LoginItemSettings()
    @EnvironmentObject private var updateChecker: UpdateChecker

    @State private var updateTask: Task<Void, Never>?

    var body: some View {
        Form {
            Section {
                Toggle("settings_launch_at_login", isOn: Binding(
                    get: { loginItem.isRegistered }, set: { loginItem.setEnabled($0) }
                ))
                if loginItem.status == .requiresApproval {
                    Button("settings_login_approval") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                }
            }
            Section("settings_sampling") {
                intervalPicker("settings_update_interval", selection: $updateInterval)
                intervalPicker("settings_background_interval", selection: Binding(
                    get: { backgroundInterval ?? MonitoringPreferences().backgroundInterval },
                    set: { backgroundInterval = $0 }
                ))
                intervalPicker("settings_process_interval", selection: $processInterval)
                intervalPicker("settings_temperature_interval", selection: $temperatureInterval)
            }
            Section {
                Picker("settings_language", selection: $langManager.appLanguage) {
                    Text("English").tag("en")
                    Text("Русский").tag("ru")
                    Text("Deutsch").tag("de")
                }
                .pickerStyle(.menu)
            }
            Section("settings_updates") {
                Toggle(
                    "updates_automatic_checks",
                    isOn: $automaticUpdateChecks
                )
                Toggle(
                    "updates_include_prereleases",
                    isOn: $includePrereleaseUpdates
                )
                .disabled(updateTask != nil || updateChecker.isChecking)
                HStack {
                    Button("updates_check") {
                        guard updateTask == nil && !updateChecker.isChecking else {
                            return
                        }
                        
                        let includePrereleases = includePrereleaseUpdates

                        updateTask = Task { @MainActor in
                            defer { updateTask = nil }

                            guard !Task.isCancelled,
                                !updateChecker.isChecking else {
                                return
                            }

                            let preferences = UpdatePreferences()
                            if preferences.automaticChecksEnabled {
                                preferences.recordAttempt(at: Date())
                            }

                            await updateChecker.checkForUpdates(
                                includePrereleases: includePrereleases
                            )
                        }
                    }
                    .disabled(updateTask != nil || updateChecker.isChecking)

                    if updateChecker.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                updateStatus
                    .font(.caption)
            }
            Section {
                Button("setup_reopen") {
                    NotificationCenter.default.post(name: .init("VitalsShowSetup"), object: nil)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loginItem.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItem.refresh()
        }
        .alert("settings_login_error", isPresented: Binding(
            get: { loginItem.errorMessage != nil },
            set: { if !$0 { loginItem.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { loginItem.errorMessage = nil }
        } message: {
            Text(verbatim: loginItem.errorMessage ?? "")
        }
        .onDisappear {
            updateTask?.cancel()
        }
        .onChange(of: includePrereleaseUpdates) { _, _ in
            updateChecker.reset()
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch updateChecker.state {
        case .idle:
            EmptyView()

        case .checking:
            Text("updates_checking")
                .foregroundStyle(.secondary)

        case .upToDate:
            Text("updates_up_to_date")
                .foregroundStyle(.secondary)

        case .updateAvailable(let release):
            HStack {
                Text("updates_available")
                Text(verbatim: release.tagName)
                    .monospacedDigit()
                Spacer()
                Link("updates_open_release", destination: release.htmlUrl)
            }

        case .failed:
            Text("updates_failed")
                .foregroundStyle(.red)
        }
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
