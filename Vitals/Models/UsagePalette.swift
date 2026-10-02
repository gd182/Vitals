import SwiftUI

struct UsagePalette: DynamicProperty {
    @AppStorage("usageColorNormal") private var normal: Int?
    @AppStorage("usageColorWarning") private var warning: Int?
    @AppStorage("usageColorCritical") private var critical: Int?

    func color(for category: TypeSegment) -> Color {
        let stored: Int?
        switch category {
        case .normal: stored = normal
        case .warning: stored = warning
        case .critical: stored = critical
        }
        return Self.decode(stored, fallback: category.color)
    }

    static func decode(_ stored: Int?, fallback: Color) -> Color {
        guard let stored, (0...0xFFFFFF).contains(stored) else { return fallback }
        return Color(red: Double((stored >> 16) & 255) / 255,
                     green: Double((stored >> 8) & 255) / 255,
                     blue: Double(stored & 255) / 255)
    }

    func binding(for category: TypeSegment) -> Binding<Color> {
        Binding(get: { color(for: category) }, set: { color in
            guard let value = Self.encode(color) else { return }
            switch category {
            case .normal: normal = value
            case .warning: warning = value
            case .critical: critical = value
            }
        })
    }

    static func encode(_ color: Color) -> Int? {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        let components = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
            .map { Int((min(1, max(0, $0)) * 255).rounded()) }
        return components[0] << 16 | components[1] << 8 | components[2]
    }

    func reset() {
        normal = nil
        warning = nil
        critical = nil
    }
}
