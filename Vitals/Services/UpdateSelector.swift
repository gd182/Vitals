//
//  UpdateSelector.swift
//  Vitals
//
//  Created by gd182 on 10/15/26.
//

import Foundation

nonisolated enum UpdateSelector {
    static func selectUpdate(
        from releases: [GitHubRelease],
        currentVersion: AppVersion,
        includePrereleases: Bool
    ) -> GitHubRelease? {
        var selectedRelease: GitHubRelease? = nil
        var highestVersion = currentVersion

        for release in releases {
            if (release.isDraft == true) {
                continue
            }
            if (release.isPrerelease && !includePrereleases) {
                continue
            }
            guard let version = AppVersion(release.tagName) else {
                continue
            }
            guard version > highestVersion else {
                continue
            }
            selectedRelease = release
            highestVersion = version
        }
        return selectedRelease
    }
}