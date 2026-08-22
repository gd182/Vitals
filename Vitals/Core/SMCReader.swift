//
//  ThermalStats.swift
//  Vitals
//
//  Created by Алексей on 6/28/26.
//

import IOKit

extension FourCharCode {
    init(fromString str: String) {
        precondition(str.count == 4)
        
        self = str.utf8.reduce(0) { sum, character in
            return sum << 8 | UInt32(character)
        }
    }
    
    func toString() -> String {
        return String(describing: UnicodeScalar(self >> 24 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 16 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 8  & 0xff)!) +
               String(describing: UnicodeScalar(self       & 0xff)!)
    }
}

public class SMCReader {
    
    enum DataType: UInt32 {
        case UI8  = 0x75693820  // "ui8 "
        case UI16 = 0x75693136  // "ui16"
        case UI32 = 0x75693332  // "ui32"
        case SP1E = 0x73703165  // "sp1e"
        case SP3C = 0x73703363  // "sp3c"
        case SP4B = 0x73703462  // "sp4b"
        case SP5A = 0x73703561  // "sp5a"
        case SPA5 = 0x73706135  // "spa5"
        case SP69 = 0x73703639  // "sp69"
        case SP78 = 0x73703738  // "sp78"
        case SP87 = 0x73703837  // "sp87"
        case SP96 = 0x73703936  // "sp96"
        case SPB4 = 0x73706234  // "spb4"
        case SPF0 = 0x73706630  // "spf0"
        case FLT  = 0x666C7420  // "flt "
        case FPE2 = 0x66706532  // "fpe2"
        case FP2E = 0x66703265  // "fp2e"
        case FDS  = 0x7B666473  // "{fds"
    }
    
    struct KeyData_t {
        typealias BytesAnswer_t = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                   UInt8, UInt8, UInt8, UInt8)
        struct keyInfo_t {
                var dataSize: IOByteCount32 = 0
                var dataType: UInt32 = 0
                var dataAttributes: UInt8 = 0
        }
        
        struct vers_t {
            var major: CUnsignedChar = 0
            var minor: CUnsignedChar = 0
            var build: CUnsignedChar = 0
            var reserved: CUnsignedChar = 0
            var release: CUnsignedShort = 0
        }
        
        struct LimitData_t {
            var version: UInt16 = 0
            var length: UInt16 = 0
            var cpuPLimit: UInt32 = 0
            var gpuPLimit: UInt32 = 0
            var memPLimit: UInt32 = 0
        }
        
        var key: UInt32 = 0
        var vers = vers_t()
        var pLimitData = LimitData_t()
        var keyInfo = keyInfo_t()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytesAnswer: BytesAnswer_t = (UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                                          UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                                          UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                                          UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                                          UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                                          UInt8(0), UInt8(0))
    }
    
    enum Keys: UInt8 {
        case kernelIndex = 2
        case readBytes = 5
        case writeBytes = 6
        case readIndex = 8
        case readKeyInfo = 9
        case readPLimit = 11
        case readVers = 12
    }
    
    struct Value_t {
        var key: UInt32
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var bytes: [UInt8] = Array(repeating: 0, count: 32)
        
        init(_ key: UInt32) {
            self.key = key
        }
    }
    
    private var conn: io_connect_t = 0
    
    public init() {
        var result: kern_return_t
        var iterator: io_iterator_t = 0
        let device: io_object_t
        
        let matchingDictionary: CFMutableDictionary = IOServiceMatching("AppleSMC")
        result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator)
        if result != kIOReturnSuccess {
            print("Error matching services: " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return
        }
        
        device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        if device == 0 {
            print("Error iterator: " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return
        }
        
        result = IOServiceOpen(device, mach_task_self_, 0, &conn)
        IOObjectRelease(device)
        if result != kIOReturnSuccess {
            print("Error open service: " + (String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error"))
            return
        }
    }
    
    public func close() -> kern_return_t {
        return IOServiceClose(conn)
    }
        
    private func readValue(_ value: UnsafeMutablePointer<Value_t>) -> kern_return_t {
        var input: KeyData_t = KeyData_t()
        var output:KeyData_t = KeyData_t()
        
        input.key = value.pointee.key
        input.data8 = Keys.readKeyInfo.rawValue
        
        var resultCall: kern_return_t = 0
        
        resultCall = callKey(Keys.kernelIndex.rawValue, &input, &output)
        if resultCall != kIOReturnSuccess {
            return resultCall
        }
        
        value.pointee.dataSize = UInt32(output.keyInfo.dataSize)
        value.pointee.dataType = output.keyInfo.dataType
        
        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = Keys.readBytes.rawValue
        resultCall = callKey(Keys.kernelIndex.rawValue, &input, &output)
        if resultCall != kIOReturnSuccess {
            return resultCall
        }
        
        memcpy(&value.pointee.bytes, &output.bytesAnswer, min(Int(value.pointee.dataSize), value.pointee.bytes.count))
        
        return kIOReturnSuccess
    }
        
    public func getDecodeValue(_ key: UInt32) -> Float? {
        var resultRead: kern_return_t = 0
        var  value: Value_t = Value_t(key)
        
        resultRead = readValue(&value)
        
        if resultRead != kIOReturnSuccess {
            return nil
        }
        
        if value.dataSize > 0 {
            if value.bytes.first(where: { $0 != 0 }) == nil && value.key != FourCharCode(fromString: "FS! ")
                && value.key != FourCharCode(fromString: "F0Md")
                && value.key != FourCharCode(fromString: "F1Md")
                && value.key != FourCharCode(fromString: "F0md")
                && value.key != FourCharCode(fromString: "F1md") {
                return nil
            }
            
            switch value.dataType {
            case DataType.UI8.rawValue:
                return Float(value.bytes[0])
            case DataType.UI16.rawValue:
                return Float(UInt16(bytes: (value.bytes[0], value.bytes[1])))
            case DataType.UI32.rawValue:
                return Float(UInt32(bytes: (value.bytes[0], value.bytes[1], value.bytes[2], value.bytes[3])))
            case DataType.SP1E.rawValue:
                let result: Float = Float(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1]))
                return Float(result / 16384)
            case DataType.SP3C.rawValue:
                let result: Float = Float(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1]))
                return Float(result / 4096)
            case DataType.SP4B.rawValue:
                let result: Float = Float(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1]))
                return Float(result / 2048)
            case DataType.SP5A.rawValue:
                let result: Float = Float(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1]))
                return Float(result / 1024)
            case DataType.SPA5.rawValue:
                let result: Float = Float(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1]))
                return Float(result / 32)
            case DataType.SP69.rawValue:
                let result: Float = Float(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1]))
                return Float(result / 512)
            case DataType.SP78.rawValue:
                let intValue: Float = Float(Int(value.bytes[0]) * 256 + Int(value.bytes[1]))
                return Float(intValue / 256)
            case DataType.SP87.rawValue:
                let intValue: Float = Float(Int(value.bytes[0]) * 256 + Int(value.bytes[1]))
                return Float(intValue / 128)
            case DataType.SP96.rawValue:
                let intValue: Float = Float(Int(value.bytes[0]) * 256 + Int(value.bytes[1]))
                return Float(intValue / 64)
            case DataType.SPB4.rawValue:
                let intValue: Float = Float(Int(value.bytes[0]) * 256 + Int(value.bytes[1]))
                return Float(intValue / 16)
            case DataType.SPF0.rawValue:
                let intValue: Float = Float(Int(value.bytes[0]) * 256 + Int(value.bytes[1]))
                return intValue
            case DataType.FLT.rawValue:
                let valueBuf: Float? = Float(value.bytes)
                if valueBuf != nil {
                    return Float(valueBuf!)
                }
                return nil
            case DataType.FPE2.rawValue:
                return Float(Int(fromFPE2: (value.bytes[0], value.bytes[1])))
            default:
                return nil
            }
        }
        
        return nil
        
    }
    
    private func callKey(_ key: UInt8,_ input: inout KeyData_t, _ output: inout KeyData_t) -> kern_return_t {
        var outputSize = MemoryLayout<KeyData_t>.stride
        return IOConnectCallStructMethod(conn, UInt32(key), &input, MemoryLayout<KeyData_t>.stride, &output, &outputSize)
    }
}

extension UInt16 {
    init(bytes: (UInt8, UInt8)) {
        self = UInt16(bytes.0) << 8 | UInt16(bytes.1)
    }
}

extension UInt32 {
    init(bytes: (UInt8, UInt8, UInt8, UInt8)) {
        self = UInt32(bytes.0) << 24 | UInt32(bytes.1) << 16 | UInt32(bytes.2) << 8 | UInt32(bytes.3)
    }
}

extension Int {
    init(fromFPE2 bytes: (UInt8, UInt8)) {
        self = (Int(bytes.0) << 6) + (Int(bytes.1) >> 2)
    }
}

extension Float {
    init?(_ bytes: [UInt8]) {
        self = bytes.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Self.self) }
    }
}
