import Foundation

@main
struct SensorCompatibilityTests {
    static func main() {
        let families: [(String, [ChipPlatform])] = [
            ("M1", [.m1, .m1pro, .m1max, .m1ultra]),
            ("M2", [.m2, .m2pro, .m2max, .m2ultra]),
            ("M3", [.m3, .m3pro, .m3max, .m3ultra]),
            ("M4", [.m4, .m4pro, .m4max, .m4ultra]),
            ("M5", [.m5, .m5pro, .m5max, .m5ultra])
        ]
        let variants = ["", " Pro", " Max", " Ultra"]
        for (name, platforms) in families {
            for (index, platform) in platforms.enumerated() {
                assert(SensorReader.getPlatform(cpuName: "Apple \(name)\(variants[index])") == platform)
                assert(!SensorReader.keysForChip(platform).isEmpty)
            }
        }
        assert(SensorReader.getPlatform(cpuName: "Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz") == .intel)
        assert(SensorReader.getPlatform(cpuName: "Intel(R) Xeon(R) W CPU") == .intel)
        assert(SensorReader.getPlatform(cpuName: "Apple M10 Pro") == .unknown)
        assert(SensorReader.getPlatform(cpuName: "Apple M6") == .unknown)
        assert(SensorReader.getPlatform(cpuName: "Unrecognized CPU") == .unknown)
        assert(SensorReader.getPlatform(cpuName: nil) == .unknown)
        assert(SensorReader.getPlatform(cpuName: "") == .unknown)
        let fallback = SensorReader.keysForChip(.unknown)
        assert(fallback.count == Set(fallback).count)
        for (_, platforms) in families {
            assert(Set(SensorReader.keysForChip(platforms[0])).isSubset(of: Set(fallback)))
        }
        assert(UInt16(bytes: (0x12, 0x34)) == 0x1234)
        assert(UInt32(bytes: (0x12, 0x34, 0x56, 0x78)) == 0x12345678)
        print("Intel, Apple Silicon and unknown-chip classification checks passed")
    }
}
