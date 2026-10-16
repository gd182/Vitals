//
//  UpdateCheckerTests.swift
//  Vitals
//
//  Created by gd182 on 10/15/26.
//

import Foundation

// MARK: - URLProtocol Stubs

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
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
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
              ) else {
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

    override func stopLoading() {}
}

// MARK: - Tests

@main
struct UpdateCheckerTests {

    @MainActor
    static func main() async throws {

        // MARK: - Helpers

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

        // MARK: - GitHubRelease Decoding

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
        assert(
            release.htmlUrl.absoluteString ==
            "https://github.com/gd182/Vitals/releases/tag/v0.2.0"
        )
        assert(release.body == nil)
        assert(release.isPrerelease)
        assert(!release.isDraft)

        print("Release decoding checks passed")

        // MARK: - AppVersion Parsing and Comparison

        assert(AppVersion("v0.2.0") == AppVersion("0.2.0"))

        assert(AppVersion("0.10.0")! > AppVersion("0.9.0")!)
        assert(AppVersion("1.0.0")! > AppVersion("0.99.99")!)
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

        // MARK: - Invalid Versions

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

        // MARK: - GitHubReleaseService

        let releases = try await fetch(using: ReleaseURLProtocolStub.self)

        assert(releases.count == 1, "Expected exactly one release")
        assert(releases.first?.tagName == "v0.2.0", "Unexpected release tag")

        print("GitHubReleaseService success checks passed")

        let emptyReleases = try await fetch(using: EmptyReleasesStub.self)

        assert(emptyReleases.isEmpty, "Expected empty releases array")

        print("Empty releases checks passed")

        // MARK: - HTTP 403

        do {
            _ = try await fetch(using: ForbiddenReleasesStub.self)
            assertionFailure("Expected HTTP 403")
        } catch GitHubReleaseService.ServiceError.httpStatus(let code) {
            assert(code == 403, "Expected HTTP 403, got \(code)")
        } catch {
            throw error
        }

        print("HTTP 403 checks passed")

        // MARK: - Invalid JSON

        do {
            _ = try await fetch(using: InvalidJSONStub.self)
            assertionFailure("Expected DecodingError")
        } catch is DecodingError {
            // Expected
        } catch {
            throw error
        }

        print("Invalid JSON checks passed")

        // MARK: - UpdateSelector

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

        print("UpdateSelector checks passed")

        // MARK: - UpdateChecker: Empty Releases

        let emptyChecker = UpdateChecker(
            currentVersion: "0.1.0",
            fetchReleases: { [] }
        )

        guard case .idle = emptyChecker.state else {
            preconditionFailure("Expected initial idle state")
        }

        assert(!emptyChecker.isChecking)

        await emptyChecker.checkForUpdates(includePrereleases: false)

        guard case .upToDate = emptyChecker.state else {
            preconditionFailure("Expected upToDate for empty releases")
        }

        assert(!emptyChecker.isChecking)

        // MARK: - UpdateChecker: Update Available

        let newUpdateChecker = UpdateChecker(
            currentVersion: "0.1.0",
            fetchReleases: {
                [makeRelease(tag: "v0.2.0")]
            }
        )

        await newUpdateChecker.checkForUpdates(includePrereleases: false)

        guard case .updateAvailable(let newRelease) = newUpdateChecker.state else {
            preconditionFailure("Expected available update")
        }

        assert(newRelease.tagName == "v0.2.0")
        assert(!newUpdateChecker.isChecking)

        // Reset after update found
        newUpdateChecker.reset()

        guard case .idle = newUpdateChecker.state else {
            preconditionFailure("Expected idle after reset")
        }

        assert(!newUpdateChecker.isChecking)

        // MARK: - UpdateChecker: Invalid Current Version (nil)

        let invalidChecker = UpdateChecker(
            currentVersion: nil,
            fetchReleases: {
                preconditionFailure("fetchReleases must not be called")
            }
        )

        await invalidChecker.checkForUpdates(includePrereleases: false)

        guard case .failed(let invalidError) = invalidChecker.state,
              case UpdateChecker.CheckError.invalidCurrentVersion = invalidError else {
            preconditionFailure("Expected invalidCurrentVersion")
        }

        assert(!invalidChecker.isChecking)

        // MARK: - UpdateChecker: Invalid Current Version (wrong)

        let wrongVersionChecker = UpdateChecker(
            currentVersion: "wrong",
            fetchReleases: {
                preconditionFailure("fetchReleases must not be called")
            }
        )

        await wrongVersionChecker.checkForUpdates(includePrereleases: false)

        guard case .failed(let wrongVersionError) = wrongVersionChecker.state,
              case UpdateChecker.CheckError.invalidCurrentVersion = wrongVersionError else {
            preconditionFailure("Expected invalidCurrentVersion")
        }

        assert(!wrongVersionChecker.isChecking)

        // MARK: - UpdateChecker: Network Error

        let networkChecker = UpdateChecker(
            currentVersion: "0.1.0",
            fetchReleases: {
                throw URLError(.notConnectedToInternet)
            }
        )

        await networkChecker.checkForUpdates(includePrereleases: false)

        guard case .failed(let networkError as URLError) = networkChecker.state else {
            preconditionFailure("Expected URLError")
        }

        assert(networkError.code == .notConnectedToInternet)
        assert(!networkChecker.isChecking)

        // Reset after network error
        networkChecker.reset()

        guard case .idle = networkChecker.state else {
            preconditionFailure("Expected idle after network error reset")
        }

        assert(!networkChecker.isChecking)

        // MARK: - UpdateChecker: CancellationError

        let cancelledChecker = UpdateChecker(
            currentVersion: "0.1.0",
            fetchReleases: {
                throw CancellationError()
            }
        )

        await cancelledChecker.checkForUpdates(includePrereleases: false)

        guard case .idle = cancelledChecker.state else {
            preconditionFailure("Expected idle after cancellation")
        }

        assert(!cancelledChecker.isChecking)

        // MARK: - UpdateChecker: URLError.cancelled

        let urlCancelledChecker = UpdateChecker(
            currentVersion: "0.1.0",
            fetchReleases: {
                throw URLError(.cancelled)
            }
        )

        await urlCancelledChecker.checkForUpdates(includePrereleases: false)

        guard case .idle = urlCancelledChecker.state else {
            preconditionFailure("Expected idle after URL cancellation")
        }

        assert(!urlCancelledChecker.isChecking)

        // MARK: - UpdateChecker: Concurrent Requests

        var requestCount = 0
        var finishRequest: CheckedContinuation<[GitHubRelease], Never>?

        let (started, startSignal) = AsyncStream<Void>.makeStream()

        let concurrentChecker = UpdateChecker(
            currentVersion: "0.1.0",
            fetchReleases: {
                requestCount += 1

                return await withCheckedContinuation { continuation in
                    finishRequest = continuation
                    startSignal.yield(())
                }
            }
        )

        let firstTask = Task { @MainActor in
            await concurrentChecker.checkForUpdates(includePrereleases: false)
        }

        var iterator = started.makeAsyncIterator()
        _ = await iterator.next()

        assert(concurrentChecker.isChecking)
        assert(requestCount == 1)

        // Second request must be ignored
        await concurrentChecker.checkForUpdates(includePrereleases: false)

        assert(concurrentChecker.isChecking)
        assert(requestCount == 1)

        // Reset must be ignored while checking
        concurrentChecker.reset()

        assert(concurrentChecker.isChecking)
        assert(requestCount == 1)

        guard let continuation = finishRequest else {
            preconditionFailure("Expected a pending request")
        }

        finishRequest = nil

        continuation.resume(returning: [])
        startSignal.finish()

        await firstTask.value

        guard case .upToDate = concurrentChecker.state else {
            preconditionFailure("Expected upToDate after completion")
        }

        assert(!concurrentChecker.isChecking)
        assert(requestCount == 1)

        // MARK: - UpdateChecker: Cancellation During Active Request

        var requestContinuation: CheckedContinuation<[GitHubRelease], Error>?

        let (cancelStarted, cancelStartSignal) = AsyncStream<Void>.makeStream()

        let activeChecker = UpdateChecker(
            currentVersion: "0.1.0",
            fetchReleases: {
                try await withCheckedThrowingContinuation { continuation in
                    requestContinuation = continuation
                    cancelStartSignal.yield(())
                }
            }
        )

        let task = Task { @MainActor in
            await activeChecker.checkForUpdates(includePrereleases: false)
        }

        var cancelIterator = cancelStarted.makeAsyncIterator()
        _ = await cancelIterator.next()

        assert(activeChecker.isChecking)

        guard case .checking = activeChecker.state else {
            preconditionFailure("Expected checking state")
        }

        task.cancel()

        guard let pendingRequest = requestContinuation else {
            preconditionFailure("Expected a pending request")
        }

        requestContinuation = nil

        // Return an update even though the task has been cancelled
        pendingRequest.resume(
            returning: [makeRelease(tag: "v0.2.0")]
        )

        cancelStartSignal.finish()

        await task.value

        guard case .idle = activeChecker.state else {
            preconditionFailure("Expected idle after cancellation")
        }

        assert(!activeChecker.isChecking)

        // Reset after cancellation
        activeChecker.reset()

        guard case .idle = activeChecker.state else {
            preconditionFailure("Expected idle after reset")
        }

        assert(!activeChecker.isChecking)

        print("All UpdateChecker tests passed")
    }
}