//
//  Format.swift
//  Vitals
//
//  Created by Алексей on 8/20/26.
//

enum Format {
    static func formatBytes(_ bytes: UInt64) -> String {
        if bytes < 1_024 {
            return "\(bytes) B"
        } else if bytes < 1_048_576 {
            return String(format: "%.0f KB", Double(bytes) / 1_024)
        } else if bytes < 1_073_741_824 {
            return String(format: "%.0f MB", Double(bytes) / 1_048_576)
        } else {
            return String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
        }
    }
}
