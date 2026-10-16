//
//  UpdateCheckerTests.swift
//  Vitals
//
//  Created by gd182 on 10/15/26.
//

import Foundation

final class EmptyReleasesStub: ReleaseURLProtocolStub, @unchecked Sendable {
    override class var responseJSON: String { "[]" }
}

final class ForbiddenReleasesStub: ReleaseURLProtocolStub, @unchecked Sendable {
    override class var responseStatusCode: Int { 403 }
    override class var responseJSON: String { "Forbidden" }
}

final class InvalidJSONStub: ReleaseURLProtocolStub, @unchecked Sendable {
    override class var responseJSON: String { "not JSON" }
}

class ReleaseURLProtocolStub: URLProtocol, @unchecked Sendable {
    class var responseStatusCode: Int { 200 }

    class var responseJSON: String {
       """
        [
            {
                "tag_name": "v0.2.0",
                "name": null,
                "html_url": "https://github.com/gd182/Vitals/releases/tag/v0.2.0",
                "body": null,
                "prerelease": true,
                "draft": false,
                "extra_field": "ignored"
            }
        ]
        """
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        let expectedURL = "https://api.github.com/repos/gd182/Vitals/releases?per_page=100"
        assert(
            request.url?.absoluteString == expectedURL,
            "Unexpected request URL"
        )
        assert(
            request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json",
            "Unexpected Accept header"
        )
        assert(
            request.value(forHTTPHeaderField: "User-Agent") == "Vitals",
            "Unexpected User-Agent header"
        )
        assert(
            request.timeoutInterval == 20,
            "Unexpected request timeout"
        )

        guard let url = request.url,
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: type(of: self).responseStatusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                ) 
        else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badURL)    
            )
            return
        }
        let data = Data(type(of: self).responseJSON.utf8)

        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {

    }
}

@main
struct UpdateCheckerTests {
    @MainActor static func main() async throws {
        func fetch(using stub: URLProtocol.Type) async throws -> [GitHubRelease] {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [stub]
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            let service = GitHubReleaseService(session: session)
            return try await service.fetchReleases()
        }

        func makeRelease(
            tag: String,
            prerelease: Bool = false,
            draft: Bool = false
        ) -> GitHubRelease {
            GitHubRelease(
                tagName: tag,
                name: nil,
                htmlUrl: URL(
                    string: "https://github.com/gd182/Vitals/releases/tag/\(tag)"
                )!,
                body: nil,
                isPrerelease: prerelease,
                isDraft: draft
            )
        }

        let json = """
        {
            "tag_name": "v0.2.0",
            "name": null,
            "html_url": "https://github.com/gd182/Vitals/releases/tag/v0.2.0",
            "body": null,
            "prerelease": true,
            "draft": false,
            "extra_field": "ignored"
        }
        """

        let data = Data(json.utf8)
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

        assert(release.tagName == "v0.2.0")
        assert(release.name == nil)
        assert(release.htmlUrl.absoluteString == "https://github.com/gd182/Vitals/releases/tag/v0.2.0")
        assert(release.body == nil)
        assert(release.isPrerelease == true)
        assert(release.isDraft == false)

        print("Release decoding checks passed")

        // MARK: - AppVersion parsing and comparison

        // GitHub tag prefix
        assert(AppVersion("v0.2.0") == AppVersion("0.2.0"))

        // Minor version comparison
        assert(AppVersion("0.10.0")! > AppVersion("0.9.0")!)

        // Major version comparison
        assert(AppVersion("1.0.0")! > AppVersion("0.99.99")!)

        // Patch version comparison
        assert(AppVersion("0.2.1")! > AppVersion("0.2.0")!)

        assert(AppVersion("v0.2.0") != nil)
        assert(AppVersion("vv1.2.3") == nil)
        assert(AppVersion("1.2.") == nil)
        assert(AppVersion("1..3") == nil)
        assert(AppVersion("+1.2.3") == nil)
        assert(AppVersion(" 1.2.3") == nil)
        assert(AppVersion("1.2.999999999999999999999999999999") == nil)

        let version = AppVersion("1.2.3")!
        assert(!(version < version))

        print("AppVersion comparison checks passed")

        // MARK: - Invalid versions

        let invalidVersions = [
            "",
            "0.2",
            "0..2",
            "-1.2.3",
            "1.2.3.4",
            "1.2.3-beta.1"
        ]

        for version in invalidVersions {
            assert(
                AppVersion(version) == nil,
                "Expected invalid version: '\(version)'"
            )
        }

        print("AppVersion invalid format checks passed")

        let releases = try await fetch(using: ReleaseURLProtocolStub.self)

        assert(releases.count == 1, "Expected exactly one release")
        assert(releases.first?.tagName == "v0.2.0", "Unexpected release tag")

        print("GitHubReleaseService success checks passed")

        let emptyReleases = try await fetch(using: EmptyReleasesStub.self)

        assert(emptyReleases.isEmpty, "Expected empty releases array")

        print("Empty releases checks passed")

        do {
            _ = try await fetch(using: ForbiddenReleasesStub.self)
            assertionFailure("Expected HTTP 403")
        } catch GitHubReleaseService.ServiceError.httpStatus(let code) {
            assert(code == 403, "Expected HTTP 403, got \(code)")
        } catch {
            throw error
        }

        print("HTTP 403 checks passed")


        do {
            _ = try await fetch(using: InvalidJSONStub.self)
            assertionFailure("Expected DecodingError")
        } catch is DecodingError {
        } catch {
            throw error
        }
        print("Invalid JSON checks passed")

        let candidates = [
            makeRelease(tag: "v0.5.0"),
            makeRelease(tag: "v0.2.0"),
            makeRelease(tag: "v0.3.0")
        ]

        let result = UpdateSelector.selectUpdate(
            from: candidates,
            currentVersion: AppVersion("0.1.0")!,
            includePrereleases: false
        )
        assert(result?.tagName == "v0.5.0", "Expected latest version v0.5.0")

        let currentVersion = AppVersion("0.1.0")!

        assert(
            UpdateSelector.selectUpdate(
                from: [],
                currentVersion: currentVersion,
                includePrereleases: false
            ) == nil
        )
        
        assert(
            UpdateSelector.selectUpdate(
                from: [
                    makeRelease(tag: "v0.0.9"),
                    makeRelease(tag: "v0.1.0")
                ],
                currentVersion: currentVersion,
                includePrereleases: false
            ) == nil
        )

        let draftCandidates = [
            makeRelease(tag: "v0.9.0", draft: true),
            makeRelease(tag: "v0.2.0")
        ]

        assert(
            UpdateSelector.selectUpdate(
                from: draftCandidates,
                currentVersion: currentVersion,
                includePrereleases: false
            )?.tagName == "v0.2.0"
        )

        // 4. Prereleases disabled
        let prereleaseCandidates = [
            makeRelease(tag: "v0.3.0", prerelease: true),
            makeRelease(tag: "v0.2.0")
        ]

        assert(
            UpdateSelector.selectUpdate(
                from: prereleaseCandidates,
                currentVersion: currentVersion,
                includePrereleases: false
            )?.tagName == "v0.2.0"
        )

        assert(
            UpdateSelector.selectUpdate(
                from: prereleaseCandidates,
                currentVersion: currentVersion,
                includePrereleases: true
            )?.tagName == "v0.3.0"
        )

        let invalidCandidates = [
            makeRelease(tag: "not-a-version"),
            makeRelease(tag: "v0.2.0")
        ]

        assert(
            UpdateSelector.selectUpdate(
                from: invalidCandidates,
                currentVersion: currentVersion,
                includePrereleases: false
            )?.tagName == "v0.2.0"
        )

        print("UpdateSelector additional checks passed")

        print("UpdateSelector latest version check passed")
        print("All UpdateChecker tests passed")
    }
}