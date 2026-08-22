//
//  SensorReader.hpp
//  Vitals
//
//  Created by Алексей on 6/30/26.
//

import Darwin

enum ChipPlatform {
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

final class SensorReader {
    static let shared = SensorReader()
    var chip: ChipPlatform = .unknown
    
    private static let smc = SMCReader()
    
    private init() {
        chip = Self.detectChip()
    }
    
    func cpuTemperature() -> Float? {
        if let value = Self.smc.getDecodeValue(FourCharCode(fromString: "TC0D")), value < 110 {
            return value
        } else if let value = Self.smc.getDecodeValue(FourCharCode(fromString: "TC0E")), value < 110 {
            return value
        } else if let value = Self.smc.getDecodeValue(FourCharCode(fromString: "TC0F")), value < 110 {
            return value
        } else if let value = Self.smc.getDecodeValue(FourCharCode(fromString: "TC0P")), value < 110 {
            return value
        } else if let value = Self.smc.getDecodeValue(FourCharCode(fromString: "TC0H")), value < 110 {
            return value
        } else {
            var total: Float = 0
            var counter: Float = 0
            let list = Self.keysForChip(chip)
            list.forEach { (key: String) in
                if let value = Self.smc.getDecodeValue(FourCharCode(fromString: key)) {
                    total += value
                    counter += 1
                }
            }
            return counter > 0 ? total / counter : nil
        }
    }
    
    private static func detectChip() -> ChipPlatform {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var chars = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &chars, &size, nil, 0)
        let brand = String(cString: chars)
        
        return getPlatform(cpuName: brand)
    }
    
    static private func getPlatform(cpuName: String?) -> ChipPlatform {
        if let name = cpuName?.lowercased() {
            if name.contains("intel") {
                return .intel
            } else if name.contains("m1") {
                return name.contains("pro") ? .m1pro : name.contains("max") ? .m1max : name.contains("ultra") ? .m1ultra : .m1
            } else if name.contains("m2") {
                return name.contains("pro") ? .m2pro : name.contains("max") ? .m2max : name.contains("ultra") ? .m2ultra : .m2
            } else if name.contains("m3") {
                return name.contains("pro") ? .m3pro : name.contains("max") ? .m3max : name.contains("ultra") ? .m3ultra : .m3
            } else if name.contains("m4") {
                return name.contains("pro") ? .m4pro : name.contains("max") ? .m4max : name.contains("ultra") ? .m4ultra : .m4
            } else if name.contains("m5") {
                return name.contains("pro") ? .m5pro : name.contains("max") ? .m5max : name.contains("ultra") ? .m5ultra : .m5
            }
        }
        return .unknown
    }
    
    private static func keysForChip(_ chip: ChipPlatform) -> [String] {
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
        default:
            return []
        }
    }
}
