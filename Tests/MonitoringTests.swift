import AppKit
import Combine
import Foundation
import ObjectiveC

struct ObjCCPUUsage { var total: Float; var user: Float; var system: Float; var idle: Float }
struct ObjCCPUStatsResult { var average: ObjCCPUUsage }
struct ObjCMemoryUsage { var totalBytes: UInt64; var usedBytes: UInt64; var usedPercent: Float }
struct ObjCSwapUsage {var totalBytes: UInt64; var usedBytes: UInt64; var available: ObjCBool}
struct ObjCGPUUsage {
    var utilization: Float = 10
    var renderUtilization: Float = 5
    var tilerUtilization: Float = 2
    var aneUtilization: Float = 0
    var vramUsed: UInt64 = 100
    var vramTotal: UInt64 = 1000
}

enum ObjCMemoryPressure: Int {
    case unknown = 0
    case normal = 1
    case warning = 2
    case critical = 3
}

final class SystemMonitor {
    static let lock = NSLock()
    static var updates = 0
    static var cpuReads = 0
    static var ramReads = 0
    static var resets = 0
    static var delay: useconds_t = 0

    private static var swapResponse = ObjCSwapUsage(
        totalBytes: 4096,
        usedBytes: 1024,
        available: ObjCBool(true)
    )

    static func setSwapResponse(
        totalBytes: UInt64,
        usedBytes: UInt64,
        available: Bool
    ) {
        lock.lock()
        defer { lock.unlock() }
        swapResponse = ObjCSwapUsage(
            totalBytes: totalBytes,
            usedBytes: usedBytes,
            available: ObjCBool(available)
        )
    }

    func swapUsage() -> ObjCSwapUsage {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return Self.swapResponse
    }

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

    private static var mockMemoryPressure: ObjCMemoryPressure = .normal

    static func setMemoryPressure(_ value: ObjCMemoryPressure) {

        lock.lock()

        defer { lock.unlock() }

        mockMemoryPressure = value

    }

    func memoryPressure() -> ObjCMemoryPressure {

        Self.lock.lock()

        defer { Self.lock.unlock() }

        return Self.mockMemoryPressure

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
@MainActor
struct MonitoringTests {
    static func pump(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
    static func waitUntil(_ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(3)
        while !condition() && Date() < deadline { pump(0.05) }
        assert(condition())
    }

    static func main() {
        testMenuBarMetrics()
        testRAMDetailPreferences()

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

        assert(vm!.cpuProcessState == .inactive)
        assert(vm!.ramProcessState == .inactive)

        var changes = 0
        var cancellable: AnyCancellable? = vm!.objectWillChange.sink { changes += 1 }
        pump(0.8)
        assert(SystemMonitor.count(\.updates) == 1)
        assert(SystemMonitor.count(\.cpuReads) == 0 && SystemMonitor.count(\.ramReads) == 0)
        assert(SensorReader.shared.readCount == 0 && changes == 0)
        let resetsBeforeOpening = SystemMonitor.count(\.resets)
        vm!.setPopoverVisible(true, module: "CPU")
        let changesBeforeEnabling: Int = changes
        vm!.isMonitoringProcessesCPU = true
        vm!.isMonitoringProcessesRAM = true
        assert(vm!.cpuProcessState == .loading)
        assert(vm!.ramProcessState == .loading)
        assert(changes == changesBeforeEnabling + 2)
        vm!.isMonitoringTemperature = true
        waitUntil { vm!.ramProcessState == .ready }
        assert(vm!.cpuProcessState == .loading)
        let changesBeforeSamples = changes
        waitUntil { vm!.cpuProcessState == .ready }
        let sampleChanges = changes - changesBeforeSamples
        print("Sample notifications: \(sampleChanges)")
        assert(SystemMonitor.count(\.cpuReads) == 2)
        assert((1...2).contains(SystemMonitor.count(\.ramReads)))
        assert((1...2).contains(SensorReader.shared.readCount))

        assert(vm!.topProcessesByCPU.first?.name == "CPU test")
        assert(vm!.cpuTemperature == 45)
        SensorReader.shared.setTemperature(nil)
        waitUntil { vm!.cpuTemperature == nil }
        waitUntil { vm!.ramProcessState == ProcessListState.ready }
        waitUntil { vm!.cpuProcessState == ProcessListState.ready }

        vm!.setPopoverVisible(false, module: "CPU")
        vm!.isMonitoringProcessesRAM = false

        assert(vm!.cpuProcessState == ProcessListState.inactive)
        assert(vm!.ramProcessState == ProcessListState.inactive)
        assert(vm!.topProcessesByCPU.isEmpty)
        assert(vm!.topProcessesByRAM.isEmpty)
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

        testRAMMonitoring()
        testCPUMonitoring()
        testCPUPendingSampleCancellation()
        testMonitoringSleepWake()
        testRAMDetailsWithoutProcesses()
        testMemoryPressureTransitions()

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

    static func testRAMDetailPreferences() {
        let suite = "VitalsTests.RAMDetailPreferences.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let original = MonitoringPreferences(defaults: defaults)
        assert(original.ramShowSwap)
        assert(original.ramShowMemoryPressure)
        assert(original.ramDetailsVisible)

        for mask in 0..<8 {
            defaults.setVolatileDomain([
                "ramShowSwap": mask & 1 != 0,
                "ramShowMemoryPressure": mask & 2 != 0,
                "RAM.ram_details.visible": mask & 4 != 0
            ], forName: UserDefaults.argumentDomain)
            let preferences = MonitoringPreferences(defaults: defaults)
            assert(preferences.ramShowSwap == (mask & 1 != 0))
            assert(preferences.ramShowMemoryPressure == (mask & 2 != 0))
            assert(preferences.ramDetailsVisible == (mask & 4 != 0))
        }

        let keys = ["ramShowSwap", "ramShowMemoryPressure", "RAM.ram_details.visible"]
        for key in keys {
            defaults.setVolatileDomain([key: false], forName: UserDefaults.argumentDomain)
            assert(MonitoringPreferences(defaults: defaults) != original)
        }
        defaults.setVolatileDomain(
            Dictionary(uniqueKeysWithValues: keys.map { ($0, "invalid") }),
            forName: UserDefaults.argumentDomain
        )
        assert(MonitoringPreferences(defaults: defaults) == original)
        print("RAM detail preference defaults, combinations and change detection checks passed")
    }

    static func testMenuBarMetrics() {
        let metrics = MenuBarMetrics()

        metrics.update(cpu: 10, ram: 20, gpu: 30)

        var cpuChanges = 0
        var ramChanges = 0
        var gpuChanges = 0

        let cpuSubscription = metrics.cpu.objectWillChange.sink {
            cpuChanges += 1
        }

        let ramSubscription = metrics.ram.objectWillChange.sink {
            ramChanges += 1
        }

        let gpuSubscription = metrics.gpu.objectWillChange.sink {
            gpuChanges += 1
        }

        metrics.update(cpu: 15, ram: 20, gpu: 30)

        assert(metrics.cpu.value == 15)
        assert(metrics.ram.value == 20)
        assert(metrics.gpu.value == 30)

        assert(cpuChanges == 1)
        assert(ramChanges == 0)
        assert(gpuChanges == 0)

        metrics.cpu.update(from: 10.1)
        let changesBeforeSameValue = cpuChanges

        metrics.cpu.update(from: 10.4)

        assert(metrics.cpu.value == 10)
        assert(cpuChanges == changesBeforeSameValue)

        metrics.cpu.update(from: 10.6)

        assert(metrics.cpu.value == 11)
        assert(cpuChanges == changesBeforeSameValue + 1)

        metrics.cpu.update(from: 42)
        let beforeNaN = cpuChanges

        metrics.cpu.update(from: .nan)

        assert(metrics.cpu.value == 0)
        assert(cpuChanges == beforeNaN + 1)

        metrics.cpu.update(from: 42)
        let beforeInfinity = cpuChanges

        metrics.cpu.update(from: .infinity)

        assert(metrics.cpu.value == 0)
        assert(cpuChanges == beforeInfinity + 1)

        metrics.cpu.update(from: 42)
        let beforeOverflow = cpuChanges

        metrics.cpu.update(from: Float.greatestFiniteMagnitude)

        assert(metrics.cpu.value == 0)
        assert(cpuChanges == beforeOverflow + 1)

        let beforeRepeatedReset = cpuChanges

        metrics.cpu.update(from: .nan)
        metrics.cpu.update(from: .infinity)
        metrics.cpu.update(from: Float.greatestFiniteMagnitude)

        assert(metrics.cpu.value == 0)
        assert(cpuChanges == beforeRepeatedReset)

        withExtendedLifetime((
            cpuSubscription,
            ramSubscription,
            gpuSubscription
        )) {}

        print("MenuBarMetrics checks passed")
    }

    static func testRAMMonitoring() {
        SystemMonitor.lock.lock()
        SystemMonitor.delay = 0
        SystemMonitor.lock.unlock()

        let defaults = UserDefaults(
            suiteName: "VitalsTests.RAM.\(UUID())"
        )!

        defaults.setVolatileDomain(
            [
                "updateInterval": 60.0,
                "backgroundUpdateInterval": 60.0,
                "processUpdateInterval": 60.0,
                "temperatureUpdateInterval": 60.0
            ],
            forName: UserDefaults.argumentDomain
        )

        let vm = SystemViewModel(defaults: defaults)

        assert(vm.swapTotalBytes == nil)
        assert(vm.swapUsedBytes == nil)
        assert(vm.ramProcessState == .inactive)

        SystemMonitor.setSwapResponse(
            totalBytes: 4096,
            usedBytes: 1024,
            available: true
        )

        vm.setPopoverVisible(true, module: "RAM")
        vm.isMonitoringProcessesRAM = true

        assert(vm.ramProcessState == .loading)

        waitUntil {
            vm.ramProcessState == .ready
        }

        assert(
            vm.topProcessesByRAM.contains {
                $0.name == "RAM test"
            }
        )

        assert(vm.swapTotalBytes == 4096)
        assert(vm.swapUsedBytes == 1024)

        vm.setPopoverVisible(false, module: "RAM")

        SystemMonitor.setSwapResponse(
            totalBytes: 8192,
            usedBytes: 2048,
            available: false
        )

        vm.setPopoverVisible(true, module: "RAM")

        waitUntil {
            vm.swapTotalBytes == nil &&
            vm.swapUsedBytes == nil
        }

        vm.setPopoverVisible(false, module: "RAM")

        SystemMonitor.setSwapResponse(
            totalBytes: 0,
            usedBytes: 0,
            available: true
        )

        vm.setPopoverVisible(true, module: "RAM")

        waitUntil {
            vm.swapTotalBytes == 0 &&
            vm.swapUsedBytes == 0
        }

        assert(vm.swapTotalBytes != nil)
        assert(vm.swapUsedBytes != nil)

        vm.setPopoverVisible(false, module: "RAM")

        assert(vm.ramProcessState == .inactive)
        assert(vm.topProcessesByRAM.isEmpty)

        SystemMonitor.setSwapResponse(
            totalBytes: 4096,
            usedBytes: 1024,
            available: true
        )

        print("RAM monitoring checks passed")
    }

    static func testCPUMonitoring() {
        SystemMonitor.lock.lock()
        SystemMonitor.delay = 0
        SystemMonitor.lock.unlock()

        let defaults = UserDefaults(
            suiteName: "VitalsTests.CPU.\(UUID())"
        )!

        defaults.setVolatileDomain(
            [
                "updateInterval": 60.0,
                "backgroundUpdateInterval": 60.0,
                "processUpdateInterval": 60.0,
                "temperatureUpdateInterval": 60.0
            ],
            forName: UserDefaults.argumentDomain
        )

        let vm = SystemViewModel(defaults: defaults)

        assert(vm.cpuProcessState == .inactive)
        assert(vm.ramProcessState == .inactive)

        let cpuReadsBefore = SystemMonitor.count(\.cpuReads)

        vm.setPopoverVisible(true, module: "CPU")
        vm.isMonitoringProcessesCPU = true

        assert(vm.cpuProcessState == .loading)
        assert(vm.ramProcessState == .inactive)

        let startTime = Date()

        waitUntil {
            vm.cpuProcessState == .ready
        }

        let elapsed = Date().timeIntervalSince(startTime)

        assert(elapsed < 3.0)

        assert(
            vm.topProcessesByCPU.contains {
                $0.name == "CPU test"
            }
        )

        let cpuReadsAfterWarmup = SystemMonitor.count(\.cpuReads)

        assert(cpuReadsAfterWarmup == cpuReadsBefore + 2)

        pump(1.0)

        assert(
            SystemMonitor.count(\.cpuReads) ==
            cpuReadsAfterWarmup
        )

        assert(vm.cpuProcessState == .ready)

        vm.setPopoverVisible(false, module: "CPU")

        assert(vm.cpuProcessState == .inactive)
        assert(vm.topProcessesByCPU.isEmpty)

        print("CPU monitoring checks passed")
    }

    static func testCPUPendingSampleCancellation() {
        SystemMonitor.lock.lock()
        SystemMonitor.delay = 0
        SystemMonitor.lock.unlock()

        let defaults = UserDefaults(
            suiteName: "VitalsTests.CPUCancellation.\(UUID())"
        )!

        defaults.setVolatileDomain(
            [
                "updateInterval": 60.0,
                "backgroundUpdateInterval": 60.0,
                "processUpdateInterval": 60.0,
                "temperatureUpdateInterval": 60.0
            ],
            forName: UserDefaults.argumentDomain
        )

        let vm = SystemViewModel(defaults: defaults)

        assert(vm.cpuProcessState == .inactive)
        assert(vm.ramProcessState == .inactive)

        vm.setPopoverVisible(true, module: "CPU")
        vm.setPopoverVisible(true, module: "RAM")

        vm.isMonitoringProcessesCPU = true
        vm.isMonitoringProcessesRAM = true

        assert(vm.cpuProcessState == .loading)
        assert(vm.ramProcessState == .loading)

        waitUntil {
            vm.ramProcessState == .ready
        }

        assert(vm.swapTotalBytes == 4096)
        assert(vm.swapUsedBytes == 1024)

        assert(vm.cpuProcessState == .loading)

        vm.setPopoverVisible(false, module: "CPU")

        let cpuReadsBefore = SystemMonitor.count(\.cpuReads)

        pump(0.8)

        assert(
            SystemMonitor.count(\.cpuReads) ==
            cpuReadsBefore
        )

        assert(vm.cpuProcessState == .inactive)
        assert(vm.topProcessesByCPU.isEmpty)

        vm.setPopoverVisible(true, module: "CPU")
        vm.isMonitoringProcessesCPU = true

        assert(vm.cpuProcessState == .loading)

        waitUntil {
            vm.cpuProcessState == .ready
        }

        assert(
            SystemMonitor.count(\.cpuReads) ==
            cpuReadsBefore + 2
        )

        assert(
            vm.topProcessesByCPU.contains {
                $0.name == "CPU test"
            }
        )

        vm.setPopoverVisible(false, module: "CPU")
        vm.setPopoverVisible(false, module: "RAM")

        assert(vm.cpuProcessState == .inactive)
        assert(vm.ramProcessState == .inactive)

        assert(vm.topProcessesByCPU.isEmpty)
        assert(vm.topProcessesByRAM.isEmpty)

        print("CPU pending sample cancellation checks passed")
    }

    static func testMonitoringSleepWake() {
        SystemMonitor.lock.lock()
        SystemMonitor.delay = 0
        SystemMonitor.lock.unlock()

        let defaults = UserDefaults(
            suiteName: "VitalsTests.SleepWake.\(UUID())"
        )!

        defaults.setVolatileDomain(
            [
                "updateInterval": 0.5,
                "backgroundUpdateInterval": 0.5,
                "processUpdateInterval": 60.0,
                "temperatureUpdateInterval": 60.0
            ],
            forName: UserDefaults.argumentDomain
        )

        let vm = SystemViewModel(defaults: defaults)

        assert(vm.cpuProcessState == .inactive)

        // Start CPU monitoring.
        vm.setPopoverVisible(true, module: "CPU")
        vm.isMonitoringProcessesCPU = true

        assert(vm.cpuProcessState == .loading)

        waitUntil {
            vm.cpuProcessState == .ready
        }

        assert(
            vm.topProcessesByCPU.contains {
                $0.name == "CPU test"
            }
        )

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.willSleepNotification,
            object: nil
        )

        let updatesBeforeSleep = SystemMonitor.count(\.updates)
        pump(0.8)
        assert(
            SystemMonitor.count(\.updates) ==
            updatesBeforeSleep
        )

        let cpuReadsBeforeWake = SystemMonitor.count(\.cpuReads)

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        assert(vm.cpuProcessState == .loading)

        waitUntil {
            vm.cpuProcessState == .ready
        }

        assert(
            SystemMonitor.count(\.cpuReads) ==
            cpuReadsBeforeWake + 2
        )

        assert(
            vm.topProcessesByCPU.contains {
                $0.name == "CPU test"
            }
        )

        vm.setPopoverVisible(false, module: "CPU")

        assert(vm.cpuProcessState == .inactive)
        assert(vm.topProcessesByCPU.isEmpty)

        print("Monitoring sleep/wake checks passed")
    }

    static func testRAMDetailsWithoutProcesses() {
        SystemMonitor.lock.lock()
        SystemMonitor.delay = 0
        SystemMonitor.lock.unlock()

        SystemMonitor.setSwapResponse(
            totalBytes: 4096,
            usedBytes: 1024,
            available: true
        )

        let defaults = UserDefaults(
            suiteName: "VitalsTests.RAMDetails.\(UUID())"
        )!

        defaults.setVolatileDomain(
            [
                "updateInterval": 60.0,
                "backgroundUpdateInterval": 60.0,
                "processUpdateInterval": 60.0,
                "temperatureUpdateInterval": 60.0
            ],
            forName: UserDefaults.argumentDomain
        )

        let vm = SystemViewModel(defaults: defaults)

        // Initial state.
        assert(vm.memoryPressure == .unknown)
        assert(vm.swapTotalBytes == nil)
        assert(vm.swapUsedBytes == nil)
        assert(vm.ramProcessState == .inactive)

        // Open RAM without enabling process monitoring.
        vm.setPopoverVisible(true, module: "RAM")

        assert(vm.isMonitoringProcessesRAM == false)

        // RAM details must load independently of process monitoring.
        waitUntil {
            vm.memoryPressure == .normal &&
            vm.swapTotalBytes == 4096 &&
            vm.swapUsedBytes == 1024
        }

        assert(vm.ramProcessState == .inactive)
        assert(vm.topProcessesByRAM.isEmpty)

        vm.setPopoverVisible(false, module: "RAM")

        assert(vm.ramProcessState == .inactive)
        assert(vm.topProcessesByRAM.isEmpty)

        print("RAM details without processes checks passed")
    }

    static func testMemoryPressureTransitions() {
        let defaults = UserDefaults(
            suiteName: "VitalsTests.MemoryPressure.\(UUID())"
        )!

        defaults.setVolatileDomain(
            [
                "updateInterval": 60.0,
                "backgroundUpdateInterval": 60.0,
                "processUpdateInterval": 60.0,
                "temperatureUpdateInterval": 60.0
            ],
            forName: UserDefaults.argumentDomain
        )

        SystemMonitor.lock.lock()
        SystemMonitor.delay = 0
        SystemMonitor.lock.unlock()

        SystemMonitor.setMemoryPressure(.normal)

        defer {
            SystemMonitor.setMemoryPressure(.normal)
        }

        let vm = SystemViewModel(defaults: defaults)

        assert(!vm.isMonitoringProcessesCPU)
        assert(!vm.isMonitoringProcessesRAM)

        let states: [ObjCMemoryPressure] = [
            .normal,
            .warning,
            .critical,
            .unknown,
            .normal
        ]

        for state in states {
            SystemMonitor.setMemoryPressure(state)

            vm.setPopoverVisible(true, module: "RAM")

            waitUntil {
                vm.memoryPressure == state
            }

            vm.setPopoverVisible(false, module: "RAM")
        }

        print("Memory pressure transitions checks passed")
    }
}
