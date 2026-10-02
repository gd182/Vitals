import Foundation

nonisolated struct ProcessUsage: Identifiable, Equatable {
    let id: Int32
    let name: String
    let value: Double

    static func decode(_ raw: NSArray) -> [ProcessUsage] {
        raw.compactMap { entry in
            guard let entry = entry as? [String: Any],
                  let pid = entry["pid"] as? NSNumber,
                  let name = entry["name"] as? String,
                  let value = entry["value"] as? NSNumber else { return nil }
            return ProcessUsage(id: pid.int32Value, name: name, value: value.doubleValue)
        }
    }
}
