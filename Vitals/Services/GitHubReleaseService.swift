//
//  GitHubReleaseService.swift
//  Vitals
//
//  Created by gd182 on 10/15/26.
//

import Foundation

nonisolated struct GitHubReleaseService: Sendable {
    enum ServiceError: Error {
        case invalidResponse
        case httpStatus(Int)
    }

    private let session: URLSession
    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchReleases() async throws -> [GitHubRelease] {
        guard let url = URL(
            string: "https://api.github.com/repos/gd182/Vitals/releases?per_page=100"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        request.setValue(
            "application/vnd.github+json",
            forHTTPHeaderField: "Accept"
        )
        request.setValue(
            "Vitals",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ServiceError.httpStatus(httpResponse.statusCode)
        }

        return try JSONDecoder().decode([GitHubRelease].self, from: data)
    }
}