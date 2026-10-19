//
//  GitHubRelease.swift
//  Vitals
//
//  Created by gd182 on 18/15/26.
//

enum MenuBarModule: Hashable {
    case cpu
    case ram
    case gpu

    var title: String {
        switch self {
        case .cpu:
            return "CPU"
        case .ram:
            return "RAM"
        case .gpu:
            return "GPU"
        }
    }
}