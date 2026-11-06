//
//  UpdateChecker.swift
//  Vitals
//
//  Created by gd182 on 10/16/26.
//

import Foundation
import Combine

@MainActor
final class UpdateChecker: ObservableObject {
    enum CheckMode {
        case manual
        case automatic
    }

    enum State {
        case idle
        case checking
        case upToDate
        case updateAvailable(GitHubRelease)
        case failed(Error)
    }

    enum CheckError: Error {
        case invalidCurrentVersion
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var availableRelease: GitHubRelease? = nil

    private let currentVersion: String?
    private let fetchReleases: () async throws -> [GitHubRelease]
    private let clock: () -> Date
    private let recordSuccessfulCheck: (Date) -> Void
    private let recordAvailableRelease: (GitHubRelease?) -> Void
    private var skippedVersion: AppVersion?
    private let recordSkippedVersion: (String?) -> Void

    var isChecking: Bool {
        if case .checking = state {
            return true
        }
        return false
    }

    init(
        currentVersion: String?,
        clock: @escaping () -> Date = { Date() },
        recordSuccessfulCheck: @escaping (Date) -> Void = { _ in },
        fetchReleases: @escaping () async throws -> [GitHubRelease],
        cachedRelease: GitHubRelease? = nil,
        includePrereleases: Bool = false,
        recordAvailableRelease: @escaping (GitHubRelease?) -> Void = { _ in },
        skippedVersion: String? = nil,
        recordSkippedVersion: @escaping (String?) -> Void = { _ in }
    ) {
        self.currentVersion = currentVersion
        self.fetchReleases = fetchReleases
        self.clock = clock
        self.recordSuccessfulCheck = recordSuccessfulCheck
        self.recordAvailableRelease = recordAvailableRelease
        self.skippedVersion = skippedVersion.flatMap { AppVersion($0) }
        self.recordSkippedVersion = recordSkippedVersion

        let restoredRelease: GitHubRelease?
        if let currentVersion,
            let currentVersion = AppVersion(currentVersion) {
            restoredRelease = UpdateSelector.selectUpdate(
                from: cachedRelease.map { [$0] } ?? [],
                currentVersion: currentVersion,
                includePrereleases: includePrereleases
            )
        } else {
            restoredRelease = nil
        }

        recordAvailableRelease(restoredRelease)

        if let release = restoredRelease, !isSkipped(release) {
            availableRelease = release
        } else {
            availableRelease = nil
        }
    }

    func checkForUpdates(includePrereleases: Bool, mode: CheckMode = .manual) async {
        guard !isChecking else {
            return
        }

        guard let currentVersion,
            let version = AppVersion(currentVersion) else {
            state = .failed(CheckError.invalidCurrentVersion)
            return
        }

        state = .checking

        do {
            let releases = try await fetchReleases()
            try Task.checkCancellation()

            recordSuccessfulCheck(clock())

            if let release = UpdateSelector.selectUpdate(
                from: releases,
                currentVersion: version,
                includePrereleases: includePrereleases
            ) {
                recordAvailableRelease(release)

                if mode == .automatic && isSkipped(release) {
                    availableRelease = nil
                    state = .idle
                } else {
                    availableRelease = release
                    state = .updateAvailable(release)
                }
            } else {
                availableRelease = nil
                recordAvailableRelease(availableRelease)
                state = .upToDate
            }
        } catch is CancellationError {
            state = .idle
        } catch let error as URLError where error.code == .cancelled {
            state = .idle
        } catch {
            state = .failed(error)
        }
    }

    func reset() {
        guard !isChecking else { return }

        availableRelease = nil
        recordAvailableRelease(nil)

        state = .idle
    }

    func skipAvailableRelease() {
        if !isChecking, let release = availableRelease {
            skippedVersion = AppVersion(release.tagName)
            recordSkippedVersion(release.tagName)
            availableRelease = nil
            state = .idle
        }
    }

    private func isSkipped(_ release: GitHubRelease) -> Bool {
        guard let skippedVersion else { return false }
        guard let releaseVersion = AppVersion(release.tagName) else { return false }
        return releaseVersion == skippedVersion
    }
}