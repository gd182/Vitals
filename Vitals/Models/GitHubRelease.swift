//
//  GitHubRelease.swift
//  Vitals
//
//  Created by gd182 on 10/15/26.
//

import Foundation

nonisolated struct GitHubRelease: Decodable, Sendable {
    let tagName: String
    let name: String?
    let htmlUrl: URL
    let body: String?
    let isPrerelease: Bool
    let isDraft: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name = "name"
        case body = "body"
        case htmlUrl = "html_url"
        case isPrerelease = "prerelease"
        case isDraft = "draft"
    }
}