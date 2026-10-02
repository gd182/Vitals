import Combine
import ServiceManagement

@MainActor
final class LoginItemSettings: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published var errorMessage: String?
    private let readStatus: () -> SMAppService.Status
    private let setRegistration: (Bool) throws -> Void

    init(readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
         setRegistration: @escaping (Bool) throws -> Void = { enabled in
             if enabled {
                 try SMAppService.mainApp.register()
             } else {
                 try SMAppService.mainApp.unregister()
             }
         }) {
        self.readStatus = readStatus
        self.setRegistration = setRegistration
        status = readStatus()
    }

    var isRegistered: Bool { status == .enabled || status == .requiresApproval }

    func refresh() { status = readStatus() }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        guard enabled != isRegistered else { return }
        do {
            try setRegistration(enabled)
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }
}
