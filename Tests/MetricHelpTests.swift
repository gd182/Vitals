import Foundation

@main
struct MetricHelpTests {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let catalog = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let strings = catalog["strings"] as! [String: Any]
        assert(MetricHelpTopic.allCases.count == 7)
        assert(Set(MetricHelpTopic.allCases.map(\.titleKey)).count == 7)
        assert(Set(MetricHelpTopic.allCases.map(\.explanationKey)).count == 7)
        let keys = MetricHelpTopic.allCases.flatMap { [$0.titleKey, $0.explanationKey] } +
            ["metric_explanation", "metric_explanation_close"]
        for key in keys {
            let entry = strings[key] as! [String: Any]
            let localizations = entry["localizations"] as! [String: Any]
            for language in ["en", "ru", "de"] {
                let localization = localizations[language] as! [String: Any]
                let unit = localization["stringUnit"] as! [String: Any]
                let value = unit["value"] as! String
                assert(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       "Missing \(language) text for \(key)")
                assert(value != key && unit["state"] as? String == "translated")
            }
        }
        print("Selected RAM/GPU explanations and controls have RU/EN/DE translations")
    }
}
