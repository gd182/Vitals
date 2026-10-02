import AppKit
import Combine
import Foundation

struct ObjCCPUUsage { var total: Float; var user: Float; var system: Float; var idle: Float }
struct ObjCCPUStatsResult { var average: ObjCCPUUsage }
struct ObjCMemoryUsage { var totalBytes: UInt64; var usedBytes: UInt64; var usedPercent: Float }
struct ObjCGPUUsage {
    var utilization: Float = 10
    var renderUtilization: Float = 5
    var tilerUtilization: Float = 2
    var aneUtilization: Float = 0
    var vramUsed: UInt64 = 100
    var vramTotal: UInt64 = 1000
}

final class SystemMonitor {
    static let lock = NSLock()
    static var updates = 0
    static var cpuReads = 0
    static var ramReads = 0
    static var resets = 0
    static var delay: useconds_t = 0

    static func count(_ key: KeyPath<SystemMonitorCounters, Int>) -> Int {
        lock.lock(); defer { lock.unlock() }
        return SystemMonitorCounters(updates: updates, cpuReads: cpuReads, ramReads: ramReads, resets: resets)[keyPath: key]
    }
    func update() {
        Self.lock.lock()
        Self.updates += 1
        let delay = Self.delay
        Self.lock.unlock()
        usleep(delay)
    }
    func cpuStats() -> ObjCCPUStatsResult { .init(average: .init(total: 20, user: 15, system: 5, idle: 80)) }
    func memoryUsage() -> ObjCMemoryUsage { .init(totalBytes: 1000, usedBytes: 400, usedPercent: 40) }
    func gpuUsage() -> ObjCGPUUsage { .init() }
    func topProcessesByCPU() -> NSArray {
        Self.lock.lock(); Self.cpuReads += 1; Self.lock.unlock()
        return [["pid": 1, "name": "CPU test", "value": 10.0]]
    }
    func topProcessesByRAM() -> NSArray {
        Self.lock.lock(); Self.ramReads += 1; Self.lock.unlock()
        return [["pid": 2, "name": "RAM test", "value": 100.0]]
    }
    func resetProcessCPUHistory() {
        Self.lock.lock(); Self.resets += 1; Self.lock.unlock()
    }
}
struct SystemMonitorCounters { let updates: Int; let cpuReads: Int; let ramReads: Int; let resets: Int }

final class SensorReader {
    static let shared = SensorReader()
    private let lock = NSLock()
    private var reads = 0
    private var temperature: Float? = 45
    func cpuTemperature() -> Float? {
        lock.lock(); defer { lock.unlock() }
        reads += 1
        return temperature
    }
    func setTemperature(_ value: Float?) { lock.lock(); temperature = value; lock.unlock() }
    var readCount: Int { lock.lock(); defer { lock.unlock() }; return reads }
}

@main
struct MonitoringTests {
    static func pump(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
    static func waitUntil(_ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(3)
        while !condition() && Date() < deadline { pump(0.05) }
        assert(condition())
    }

    static func main() {
        let defaults = UserDefaults(suiteName: "VitalsTests.\(UUID())")!
        var values: [String: Any] = ["updateInterval": 0.5, "backgroundUpdateInterval": 2,
            "processUpdateInterval": 1, "temperatureUpdateInterval": 1]
        func apply() {
            defaults.setVolatileDomain(values, forName: UserDefaults.argumentDomain)
            NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        }
        apply()
        let preferences = MonitoringPreferences(defaults: defaults)
        assert(preferences.foregroundInterval == 0.5 && preferences.backgroundInterval == 2)
        assert(preferences.warningThreshold == 50 && preferences.criticalThreshold == 80)
        values["warningThreshold"] = 0
        values["criticalThreshold"] = 0
        apply()
        assert(MonitoringPreferences(defaults: defaults).criticalThreshold == 0)
        values["updateInterval"] = Double.nan
        apply()
        assert(MonitoringPreferences(defaults: defaults).foregroundInterval == 1)
        values["updateInterval"] = 0.5
        apply()

        var vm: SystemViewModel? = SystemViewModel(defaults: defaults)
        weak var weakVM = vm
        var changes = 0
        var cancellable: AnyCancellable? = vm!.objectWillChange.sink { changes += 1 }
        pump(0.8)
        assert(SystemMonitor.count(\.updates) == 1)
        assert(SystemMonitor.count(\.cpuReads) == 0 && SystemMonitor.count(\.ramReads) == 0)
        assert(SensorReader.shared.readCount == 0 && changes == 0)
        let resetsBeforeOpening = SystemMonitor.count(\.resets)
        vm!.setPopoverVisible(true, module: "CPU")
        vm!.isMonitoringProcessesCPU = true
        vm!.isMonitoringProcessesRAM = true
        vm!.isMonitoringTemperature = true
        pump(1.7)
        assert((1...2).contains(SystemMonitor.count(\.cpuReads)))
        assert((1...2).contains(SystemMonitor.count(\.ramReads)))
        assert((1...2).contains(SensorReader.shared.readCount))
        assert(changes >= 3 && changes <= 4)
        assert(vm!.topProcessesByCPU.first?.name == "CPU test")
        assert(vm!.cpuTemperature == 45)
        SensorReader.shared.setTemperature(nil)
        waitUntil { vm!.cpuTemperature == nil }
        vm!.setPopoverVisible(false, module: "CPU")
        vm!.isMonitoringProcessesRAM = false
        assert(vm!.topProcessesByCPU.isEmpty && vm!.topProcessesByRAM.isEmpty)
        let before = SystemMonitor.count(\.updates)
        pump(0.8)
        assert(SystemMonitor.count(\.updates) == before)
        vm!.setPopoverVisible(true, module: "CPU")
        vm!.isMonitoringProcessesCPU = true
        pump(0.7)
        assert(SystemMonitor.count(\.resets) >= resetsBeforeOpening + 2)

        // A slow sample must not create a queue of timer work or publish after closing its block.
        SystemMonitor.lock.lock(); SystemMonitor.delay = 1_200_000; SystemMonitor.lock.unlock()
        pump(0.6)
        let slowStart = SystemMonitor.count(\.updates)
        vm!.setPopoverVisible(false, module: "CPU")
        pump(1.4)
        assert(SystemMonitor.count(\.updates) <= slowStart + 1)
        assert(vm!.topProcessesByCPU.isEmpty)
        cancellable = nil
        vm = nil
        pump(1.3)
        assert(weakVM == nil)
        _ = cancellable

        // History stays bounded and preserves real sample dates with mixed polling intervals.
        var history = HistoryData()
        for i in 0..<1000 { history.append(Float(i % 100), timestamp: Date(timeIntervalSince1970: Double(i * 3))) }
        let segments = history.segments(warning: 0, critical: 0)
        assert(segments.allSatisfy { $0.category == .critical })
        let points = segments.flatMap(\.points)
        assert(points.count == 60)
        assert(points.first?.timestamp == Date(timeIntervalSince1970: 940 * 3))
        assert(points.last?.timestamp == Date(timeIntervalSince1970: 999 * 3))
        print("Monitoring, lifecycle, preferences and history checks passed")
    }
}
