//
//  MenuBarImageRenderer.swift
//  Vitals
//
//  Created by gd182 on 18/15/26.
//

import AppKit

@MainActor
enum MenuBarImageRenderer {

    static func render(
        module: MenuBarModule,
        percent: Int,
    ) -> NSImage {
        let imageSize = NSSize(width: 36, height: 22)

        // Prepare immutable text once; AppKit may invoke the drawing handler repeatedly.
        let titleFont = NSFont.systemFont(
            ofSize: 8,
            weight: .light
        )

        let valueFont = NSFont.monospacedSystemFont(
            ofSize: 12,
            weight: .bold
        )

        let title = NSAttributedString(
            string: module.title,
            attributes: [
                .font: titleFont,
                .foregroundColor: NSColor.black
            ]
        )

        let value = NSAttributedString(
            string: "\(percent)%",
            attributes: [
                .font: valueFont,
                .foregroundColor: NSColor.black
            ]
        )

        let titleSize = title.size()
        let valueSize = value.size()

        let image = NSImage(
            size: imageSize,
            flipped: false
        ) { rect in

            let titleRect = NSRect(
                x: (rect.width - titleSize.width) / 2,
                y: rect.height - titleSize.height,
                width: titleSize.width,
                height: titleSize.height
            )

            let valueRect = NSRect(
                x: (rect.width - valueSize.width) / 2,
                y: 0,
                width: valueSize.width,
                height: valueSize.height
            )

            title.draw(in: titleRect)
            value.draw(in: valueRect)

            return true
        }

        image.isTemplate = true

        return image
    }
}
