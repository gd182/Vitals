import Foundation
import ServiceManagement

@main
struct LoginItemTests {
    @MainActor static func main() {
        var status: SMAppService.Status = .notRegistered
        var writes = 0
        var fail = false
        let settings = LoginItemSettings(readStatus: { status }, setRegistration: { enabled in
            writes += 1
            if fail { throw NSError(domain: "LoginItemTests", code: 1) }
            status = enabled ? .requiresApproval : .notRegistered
        })
        assert(!settings.isRegistered && writes == 0)
        settings.refresh()
        assert(writes == 0)
        settings.setEnabled(true)
        assert(settings.isRegistered && settings.status == .requiresApproval && writes == 1)
        settings.setEnabled(true)
        assert(writes == 1)
        status = .enabled
        settings.refresh()
        assert(settings.status == .enabled)
        fail = true
        settings.setEnabled(false)
        assert(settings.isRegistered && settings.errorMessage != nil)
        fail = false
        settings.setEnabled(false)
        assert(!settings.isRegistered && settings.errorMessage == nil)
        status = .notFound
        settings.refresh()
        assert(!settings.isRegistered)
        print("Login item status, approval and failure checks passed (no real registration)")
    }
}
