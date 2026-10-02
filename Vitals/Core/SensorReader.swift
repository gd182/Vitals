//
//  SensorReader.hpp
//  Vitals
//
//  Created by Алексей on 6/30/26.
//

import Darwin
import Foundation

nonisolated enum ChipPlatform: Equatable {
    case intel
    
    case m1
    case m1pro
    case m1max
    case m1ultra
    
    case m2
    case m2pro
    case m2max
    case m2ultra
    
    case m3
    case m3pro
    case m3max
    case m3ultra
    
    case m4
    case m4pro
    case m4max
    case m4ultra
    
    case m5
    case m5pro
    case m5max
    case m5ultra
    
    case unknown
}

nonisolated final class SensorReader {
    static let shared = SensorReader()
    var chip: ChipPlatform = .unknown
    
    private static let smc = SMCReader()
    
    private init() {
        chip = Self.detectChip()
    }
    
    private var temperatureKeys: [FourCharCode]?
    private var nextDiscoveryTime: TimeInterval = 0

    func cpuTemperature() -> Float? {
        let now = ProcessInfo.processInfo.systemUptime
        func read(_ key: FourCharCode) -> Float? {
            guard let value = Self.smc.getDecodeValue(key), value.isFinite, value > 0, value < 110 else { return nil }
            return value
        }
        if let keys = temperatureKeys {
            let values = keys.compactMap(read)
            if !values.isEmpty { return values.reduce(0, +) / Float(values.count) }
            temperatureKeys = nil
            nextDiscoveryTime = now + 60
        }
        guard now >= nextDiscoveryTime else { return nil }
        for name in ["TC0D", "TC0E", "TC0F", "TC0P", "TC0H"] {
            let key = FourCharCode(fromString: name)
            if let value = read(key) {
                temperatureKeys = [key]
                return value
            }
        }
        var keys: [FourCharCode] = []
        var values: [Float] = []
        for name in Self.keysForChip(chip) {
            let key = FourCharCode(fromString: name)
            if let value = read(key) {
                keys.append(key)
                values.append(value)
            }
        }
        guard !values.isEmpty else {
            nextDiscoveryTime = now + 60
            return nil
        }
        temperatureKeys = keys
        return values.reduce(0, +) / Float(values.count)
    }
    
    private static func detectChip() -> ChipPlatform {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else {
            return .unknown
        }
        var chars = [CChar](repeating: 0, count: size + 1)
        guard sysctlbyname("machdep.cpu.brand_string", &chars, &size, nil, 0) == 0 else {
            return .unknown
        }
        let brand = String(cString: chars)
        
        return getPlatform(cpuName: brand)
    }
    
    static func getPlatform(cpuName: String?) -> ChipPlatform {
        if let name = cpuName?.lowercased() {
            let words = Set(name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
            if words.contains("intel") {
                return .intel
            } else if words.contains("m1") {
                return words.contains("pro") ? .m1pro : words.contains("max") ? .m1max : words.contains("ultra") ? .m1ultra : .m1
            } else if words.contains("m2") {
                return words.contains("pro") ? .m2pro : words.contains("max") ? .m2max : words.contains("ultra") ? .m2ultra : .m2
            } else if words.contains("m3") {
                return words.contains("pro") ? .m3pro : words.contains("max") ? .m3max : words.contains("ultra") ? .m3ultra : .m3
            } else if words.contains("m4") {
                return words.contains("pro") ? .m4pro : words.contains("max") ? .m4max : words.contains("ultra") ? .m4ultra : .m4
            } else if words.contains("m5") {
                return words.contains("pro") ? .m5pro : words.contains("max") ? .m5max : words.contains("ultra") ? .m5ultra : .m5
            }
        }
        return .unknown
    }
    
    static func keysForChip(_ chip: ChipPlatform) -> [String] {
        switch chip {
        case .m1, .m1pro, .m1max, .m1ultra:
            return ["Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b"]
        case .m2, .m2pro, .m2max, .m2ultra:
            return ["Tp1h", "Tp1t", "Tp1p", "Tp1l", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j"]
        case .m3, .m3pro, .m3max, .m3ultra:
            return ["Te05", "Te0L", "Te0P", "Te0S", "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E", "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E"]
        case .m4, .m4pro, .m4max, .m4ultra:
            return ["Te05", "Te09", "Te0H", "Te0S", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e"]
        case .m5, .m5pro, .m5max, .m5ultra:
            return ["Tp00", "Tp04", "Tp08", "Tp0C", "Tp0G", "Tp0K", "Tp0O", "Tp0R", "Tp0U", "Tp0X", "Tp0a", "Tp0d", "Tp0g", "Tp0j", "Tp0m", "Tp0p", "Tp0u", "Tp0y"]
        case .unknown:
            // Probe known CPU temperature keys once for unrecognized Apple Silicon generations.
            return Array(Set([ChipPlatform.m1, .m2, .m3, .m4, .m5].flatMap(keysForChip))).sorted()
        case .intel:
            return []
        }
    }
}
