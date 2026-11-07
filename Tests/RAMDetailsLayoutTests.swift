import Foundation

@main
struct RAMDetailsLayoutTests {
    static func main() throws {
        let cases: [(RAMIndicatorStyle, Bool, Bool, Bool)] = [
            (.ring, false, false, true),
            (.ring, false, true, true),
            (.ring, true, false, true),
            (.ring, true, true, true),
            (.value, false, false, true),
            (.value, false, true, true),
            (.value, true, false, false),
            (.value, true, true, true)
        ]
        var failures = 0
        for (style, indicatorsVisible, repeatValues, expected) in cases {
            let actual = RAMDetailsLayout.showsUsedAndTotal(
                indicatorStyle: style,
                indicatorsVisible: indicatorsVisible,
                repeatIndicatorValues: repeatValues
            )
            if actual != expected {
                failures += 1
                let message = "FAIL: style=\(style.rawValue), indicatorsVisible=\(indicatorsVisible), repeatValues=\(repeatValues): expected \(expected), received \(actual)\n"
                FileHandle.standardError.write(Data(message.utf8))
            }
        }
        assert(failures == 0, "RAM detail rows must stay visible unless the enabled numeric indicator replaces them")
        print("All eight RAM indicator/detail visibility combinations passed")
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let catalog = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let strings = catalog["strings"] as! [String: Any]
        for key in ["ram_repeat_indicator_values", "ram_repeat_indicator_values_help"] {
            let entry = strings[key] as! [String: Any]
            let translations = entry["localizations"] as! [String: Any]
            for language in ["en", "ru", "de"] {
                let translation = translations[language] as! [String: Any]
                let unit = translation["stringUnit"] as! [String: Any]
                let text = unit["value"] as! String
                assert(unit["state"] as? String == "translated")
                assert(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text != key)
            }
        }
        print("RAM detail repetition setting and help translations passed in RU/EN/DE")
    }
}
