import SwiftUI

@main
struct VitalsApp: App {
    //@ObservedObject private var vm = SystemViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        //MenuBarExtra() {
        //    ContentView()
        //        .environmentObject(vm)
        //} label: {
        //    MenuBarLabelView(vm: vm)
        //}
        //.menuBarExtraStyle(.window)
        
        Settings {
            LocalizedRoot(langManager: appDelegate.langManager) {
                SettingsView()
                    .environmentObject(appDelegate.langManager)
            }
        }
    }
}
