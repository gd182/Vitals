import SwiftUI

@main
struct ChartColorTests {
    @MainActor static func main() {
        let indicator = CircularIndicator(value: 18, text: "18%", label: "CPU")
        assert(indicator.value == 18 && indicator.text == "18%")
        let unavailable = CircularIndicator(value: nil, text: "N/A", label: "temp")
        assert(unavailable.value == nil)
        let scale = UsageColorScale()
        assert(UsagePalette.encode(Color(red: 1, green: 128.0 / 255, blue: 0)) == 0xFF8000)
        for value in [0, 0xFFFFFF, 0x007AFF, 0xFF2D55] {
            assert(UsagePalette.encode(UsagePalette.decode(value, fallback: .black)) == value)
        }
        assert(UsagePalette.encode(UsagePalette.decode(-1, fallback: .black)) == 0)
        assert(UsagePalette.encode(UsagePalette.decode(0x1000000, fallback: .white)) == 0xFFFFFF)
        assert(scale.category(for: 49) == .normal)
        assert(scale.category(for: 50) == .warning)
        assert(scale.category(for: 79) == .warning)
        assert(scale.category(for: 80) == .critical)
        let custom = UsageColorScale(warning: 20, critical: 40)
        assert(custom.category(for: 25) == .warning && custom.category(for: 45) == .critical)
        assert(UsageColorScale(warning: 0, critical: 0).category(for: 0) == .critical)

        func points(_ values: [Float]) -> [HistoryPoint] {
            values.enumerated().map { .init(index: $0.offset, value: $0.element, timestamp: Date()) }
        }
        let constant = scale.gradientStops(points: points([18, 18, 18]), width: 240, transitionWidth: 50)
        assert(constant.allSatisfy { $0.category == .normal })
        let peak = points([18, 18, 95, 18, 18])
        for width in [0.0, 20, 50, 1000] {
            let stops = scale.gradientStops(points: peak, width: 240, transitionWidth: width)
            assert(stops.first?.category == .normal && stops.last?.category == .normal)
            assert(stops.allSatisfy { (0...1).contains($0.location) })
            assert(zip(stops, stops.dropFirst()).allSatisfy { pair in pair.0.location <= pair.1.location })
            let red = stops.filter { $0.category == .critical }
            assert(red.count >= 2)
            assert(red.first!.location < 0.5 && red.last!.location > 0.5)
        }
        // 20 -> 80 crosses warning halfway along this symmetric cubic, not at its previous point.
        let ramp = scale.gradientStops(points: points([20, 80]), width: 200, transitionWidth: 0)
        let warningStart = ramp.first { $0.category == .warning }!
        assert(abs(warningStart.location - 0.5) < 0.00001)
        let edgeCases = [[Float(80), 10, 80], [0, 50, 80, 100], [100, 80, 50, 0]]
        for values in edgeCases {
            let stops = scale.gradientStops(points: points(values), width: 1, transitionWidth: 50)
            assert(zip(stops, stops.dropFirst()).allSatisfy { pair in pair.0.location <= pair.1.location })
        }

        if let path = ProcessInfo.processInfo.arguments.dropFirst().first {
            let defaults = UserDefaults(suiteName: "ChartColorTests.\(UUID())")!
            defaults.setVolatileDomain(["warningThreshold": 50, "criticalThreshold": 80], forName: UserDefaults.argumentDomain)
            var history = HistoryData()
            let samples: [Float] = [18, 20, 15, 20, 95, 20, 18, 16, 23, 65, 68, 20, 15, 22, 18, 20]
            samples.forEach { history.append($0) }
            let view = VStack(spacing: 12) {
                GradientLineView(segments: history.segments(warning: 50, critical: 80), namespace: "color_preview")
                GradientLineView(segments: history.segments(warning: 50, critical: 80), namespace: "color_preview")
                HStack {
                    CircularIndicator(value: 18, text: "18%", label: "CPU")
                    CircularIndicator(value: 65, text: "65%", label: "RAM")
                    CircularIndicator(value: 95, text: "95%", label: "GPU")
                    CircularIndicator(value: nil, text: "N/A", label: "temp")
                }
            }
            .padding(16).frame(width: 300).background(Color(white: 0.2))
            .environment(\.colorScheme, .dark).defaultAppStorage(defaults)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage, let data = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: data),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                preconditionFailure("Chart preview could not be rendered")
            }
            try! png.write(to: URL(fileURLWithPath: path))
        }
        print("Threshold, cubic crossing and non-overlapping gradient checks passed")
    }
}
