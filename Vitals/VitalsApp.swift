import SwiftUI

@main
struct VitalsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {
            LocalizedRoot(langManager: appDelegate.langManager) {
                SettingsView()
                    .environmentObject(appDelegate.langManager)
                    .environmentObject(appDelegate.updateChecker)
            }
        }
    }
}
