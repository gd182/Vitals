import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("Основное", systemImage: "gearshape")
                }
            
            ThresholdsSettingsView()
                .tabItem {
                    Label("Пороги", systemImage: "chart.bar")
                }
            
            AppearanceSettingsView()
                .tabItem {
                    Label("Внешний вид", systemImage: "paintbrush")
                }
            
            MenuBarSettingsView()
                .tabItem {
                    Label("Меню бар", systemImage: "menubar.rectangle")
                }
        }
        .frame(width: 400, height: 300)
    }
}



#Preview {
    SettingsView()
}
