import Foundation

nonisolated struct AppBuildInfo {
    let version: String?
    let build: String?

    init(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) {
        func metadata(_ key: String) -> String? {
            guard let value = infoDictionary?[key] as? String else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        version = metadata("CFBundleShortVersionString")
        build = metadata("CFBundleVersion")
    }
}
