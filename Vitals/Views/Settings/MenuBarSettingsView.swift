import SwiftUI

struct MenuBarSettingsView: View {
    var body: some View {
        Form {
            MenuBarModuleControls()
        }
        .formStyle(.grouped)
    }
}

struct MenuBarModuleControls: View {
    @AppStorage("menuBarCPU") private var cpu = true
    @AppStorage("menuBarRAM") private var ram = true
    @AppStorage("menuBarGPU") private var gpu = true

    var body: some View {
        Section("settings_modules") {
            Toggle("CPU", isOn: $cpu).disabled(cpu && !ram && !gpu)
            Toggle("RAM", isOn: $ram).disabled(ram && !cpu && !gpu)
            Toggle("GPU", isOn: $gpu).disabled(gpu && !cpu && !ram)
        }
        .onAppear {
            if !cpu && !ram && !gpu { cpu = true }
        }
    }
}
