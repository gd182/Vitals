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

    private let currentVersion: String?
    private let fetchReleases: () async throws -> [GitHubRelease]

    var isChecking: Bool {
        if case .checking = state {
            return true
        }
        return false
    }

    init(
        currentVersion: String?,
        fetchReleases: @escaping () async throws -> [GitHubRelease]
    ) {
        self.currentVersion = currentVersion
        self.fetchReleases = fetchReleases
    }

    func checkForUpdates(includePrereleases: Bool) async {
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
            if let release = UpdateSelector.selectUpdate(
                from: releases,
                currentVersion: version,
                includePrereleases: includePrereleases
            ) {
                state = .updateAvailable(release)
            } else {
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
        state = .idle
    }
}