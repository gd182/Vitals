import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("settings_tab_general", systemImage: "gearshape")
                }
            
            ThresholdsSettingsView()
                .tabItem {
                    Label("settings_tab_thresholds", systemImage: "chart.bar")
                }
            
            AppearanceSettingsView()
                .tabItem {
                    Label("settings_tab_appearance", systemImage: "paintbrush")
                }
            
            MenuBarSettingsView()
                .tabItem {
                    Label("settings_tab_menubar", systemImage: "menubar.rectangle")
                }
        }
        .frame(width: 400, height: 300)
    }
}



#Preview {
    SettingsView()
}
