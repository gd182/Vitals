import Foundation

@main
struct AppBuildInfoTests {
    static func main() {
        let release = AppBuildInfo(infoDictionary: [
            "CFBundleShortVersionString": "0.2.0",
            "CFBundleVersion": "42"
        ])
        assert(release.version == "0.2.0")
        assert(release.build == "42")

        for metadata: [String: Any]? in [nil, [:], [
            "CFBundleShortVersionString": " \n",
            "CFBundleVersion": 42
        ]] {
            let missing = AppBuildInfo(infoDictionary: metadata)
            assert(missing.version == nil)
            assert(missing.build == nil)
        }

        let versionOnly = AppBuildInfo(infoDictionary: [
            "CFBundleShortVersionString": " 0.2.0-beta.1 \n"
        ])
        assert(versionOnly.version == "0.2.0-beta.1")
        assert(versionOnly.build == nil)
        let buildOnly = AppBuildInfo(infoDictionary: ["CFBundleVersion": "1.2.3"])
        assert(buildOnly.version == nil)
        assert(buildOnly.build == "1.2.3")
        print("All AppBuildInfo tests passed")
    }
}
