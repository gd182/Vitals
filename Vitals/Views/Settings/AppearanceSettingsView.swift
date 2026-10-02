import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("panelWidth") private var panelWidth: Double = 360
    @State private var chart = "chart_CPU"
    @AppStorage("panelCompact") private var compact = true
    @AppStorage("panelSectionTitles") private var sectionTitles = true
    @AppStorage("chartFill") private var chartFill = true
    private var palette = UsagePalette()

    @State private var tab = 0

    init(initialTab: Int = 0) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        Form {
            Picker("settings_tab_appearance", selection: $tab) {
                Text("panel_layout").tag(0)
                Text("appearance_colors").tag(1)
                Text("appearance_charts").tag(2)
            }
            .pickerStyle(.segmented)
            if tab == 0 {
                Picker("settings_theme", selection: $appearance) {
                    Text("settings_theme_system").tag("system")
                    Text("settings_theme_light").tag("light")
                    Text("settings_theme_dark").tag("dark")
                }
                .pickerStyle(.segmented)
                Picker("panel_size", selection: $panelWidth) {
                    Text("panel_size_standard").tag(360.0)
                    Text("panel_size_wide").tag(420.0)
                }
                .pickerStyle(.segmented)
                Picker("panel_density", selection: $compact) {
                    Text("panel_compact").tag(true)
                    Text("panel_spacious").tag(false)
                }
                .pickerStyle(.segmented)
                Toggle("panel_section_titles", isOn: $sectionTitles)
                Toggle("chart_fill", isOn: $chartFill)
            } else if tab == 1 {
                Section("usage_colors") {
                    ColorPicker("usage_normal", selection: palette.binding(for: .normal), supportsOpacity: false)
                    ColorPicker("threshold_warning", selection: palette.binding(for: .warning), supportsOpacity: false)
                    ColorPicker("threshold_critical", selection: palette.binding(for: .critical), supportsOpacity: false)
                    Button { palette.reset() } label: { Image(systemName: "arrow.counterclockwise") }
                        .help("panel_reset")
                }
            } else {
                Section("panel_chart_settings") {
                    Picker("settings_modules", selection: $chart) {
                        Text("CPU").tag("chart_CPU")
                        Text("RAM").tag("chart_RAM")
                        Text("block_chart_gpu_util").tag("chart_GPU_utl")
                        Text("block_chart_gpu_render").tag("chart_GPU_render")
                        Text("block_chart_gpu_tiler").tag("chart_GPU_tiler")
                        Text("block_chart_gpu_ane").tag("chart_GPU_ane")
                    }
                    ChartControlsView(namespace: chart).id(chart)
                }
            }
        }
        .formStyle(.grouped)
    }
}
