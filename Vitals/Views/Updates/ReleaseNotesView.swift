//
//  ReleaseNotesView.swift
//  Vitals
//
//  Created by gd182 on 5/11/26.
//

import SwiftUI
import MarkdownUI

struct ReleaseNotesView: View {
    let release: GitHubRelease
    let onClose: () -> Void

    var body: some View {
        VStack {
            HStack {
                Text("updates_release_notes")
                    .font(.headline)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("updates_release_notes_close")
                .accessibilityLabel("updates_release_notes_close")
                .keyboardShortcut(.cancelAction)
            }
            Text(verbatim: release.tagName)
            ScrollView(.vertical) {
                if let body = release.body?.trimmingCharacters(in: .whitespacesAndNewlines),
                !body.isEmpty {
                    Markdown(body)
                        .markdownTheme(.gitHub)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("updates_no_release_notes")
                        .foregroundStyle(.secondary)
                }
            }
            Link("updates_open_release", destination: release.htmlUrl)
        }
        .padding()
        .frame(minWidth: 440, minHeight: 300)
    }
}