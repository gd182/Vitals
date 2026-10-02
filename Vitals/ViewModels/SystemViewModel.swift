import Combine
import Foundation
import AppKit

final class MenuBarMetrics: ObservableObject {
    @Published private(set) var cpu = 0
    @Published private(set) var ram = 0
    @Published private(set) var gpu = 0

    func update(cpu: Float, ram: Float, gpu: Float) {
        func percent(_ value: Float) -> Int { value.isFinite ? Int(value.rounded()) : 0 }
        let nextCPU = percent(cpu), nextRAM = percent(ram), nextGPU = percent(gpu)
        if self.cpu != nextCPU { self.cpu = nextCPU }
        if self.ram != nextRAM { self.ram = nextRAM }
        if self.gpu != nextGPU { self.gpu = nextGPU }
    }
}

final class SystemViewModel: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    let menuBarMetrics = MenuBarMetrics()
    private(set) var cpuUsage: Float = 0
    private(set) var memoryUsedBytes: UInt64 = 0
    private(set) var memoryPercent: Float = 0
    private(set) var cpuUser: Float = 0
    private(set) var cpuSystem: Float = 0
    private(set) var cpuIdle: Float = 0
    private(set) var cpuHistory = HistoryData()
    private(set) var memoryHistory = HistoryData()
    private(set) var gpuUtilHistory = HistoryData()
    private(set) var gpuRenderHistory = HistoryData()
    private(set) var gpuTilerHistory = HistoryData()
    private(set) var gpuANEHistory = HistoryData()
    private(set) var topProcessesByCPU: [ProcessUsage] = []
    private(set) var topProcessesByRAM: [ProcessUsage] = []
    private(set) var cpuTemperature: Float?
    private(set) var memoryTotalBytes: UInt64 = 0
    private(set) var gpuUtilization: Float = 0
    private(set) var gpuRenderUtilization: Float = 0
    private(set) var gpuTilerUtilization: Float = 0
    private(set) var gpuANEUtilization: Float = 0
    private(set) var gpuVramUsed: UInt64 = 0
    private(set) var gpuVramTotal: UInt64 = 0
    private(set) var warningThreshold: Float = 50
    private(set) var criticalThreshold: Float = 80

    var isMonitoringProcessesCPU = false {
        didSet {
            guard oldValue != isMonitoringProcessesCPU else { return }
            lastCPUProcessRead = nil
            cpuProcessGeneration += 1
            if !isMonitoringProcessesCPU {
                topProcessesByCPU = []
                let monitor = self.monitor
                monitorQueue.async { monitor.resetProcessCPUHistory() }
            }
        }
    }
    var isMonitoringProcessesRAM = false {
        didSet {
            guard oldValue != isMonitoringProcessesRAM else { return }
            lastRAMProcessRead = nil
            ramProcessGeneration += 1
            if !isMonitoringProcessesRAM { topProcessesByRAM = [] }
        }
    }
    var isMonitoringTemperature = false {
        didSet { if !isMonitoringTemperature { lastTemperatureRead = nil } }
    }

    private let monitorQueue = DispatchQueue(label: "com.vitals.monitor", qos: .utility)
    private let monitor = SystemMonitor()
    private let defaults: UserDefaults
    private var preferences: MonitoringPreferences
    private var timer: Timer?
    private var intervalObserver: NSObjectProtocol?
    private var sleepObservers: [NSObjectProtocol] = []
    private var visiblePopovers: Set<String> = []
    private var isSleeping = false
    private var sampleInFlight = false
    private var timerInterval: TimeInterval?
    private var lastCPUProcessRead: TimeInterval?
    private var lastRAMProcessRead: TimeInterval?
    private var lastTemperatureRead: TimeInterval?
    private var cpuProcessGeneration = 0
    private var ramProcessGeneration = 0
    private var sampledCPUProcessGeneration = -1

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferences = MonitoringPreferences(defaults: defaults)
        applyPreferences()
        intervalObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let next = MonitoringPreferences(defaults: self.defaults)
            guard next != self.preferences else { return }
            self.objectWillChange.send()
            self.preferences = next
            self.applyPreferences()
            self.startTimer()
        }
        let workspace = NSWorkspace.shared.notificationCenter
        sleepObservers.append(workspace.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.isSleeping = true
            self?.timer?.invalidate()
            self?.timer = nil
            self?.timerInterval = nil
        })
        sleepObservers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.isSleeping = false
            self.lastCPUProcessRead = nil
            self.lastRAMProcessRead = nil
            self.lastTemperatureRead = nil
            self.cpuProcessGeneration += 1
            self.startTimer()
            self.sample()
        })
        startTimer()
        sample()
    }

    deinit {
        timer?.invalidate()
        if let intervalObserver { NotificationCenter.default.removeObserver(intervalObserver) }
        for observer in sleepObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    func setPopoverVisible(_ visible: Bool, module: String) {
        if visible { visiblePopovers.insert(module) } else { visiblePopovers.remove(module) }
        if !visible {
            switch module {
            case "CPU":
                isMonitoringProcessesCPU = false
                isMonitoringTemperature = false
            case "RAM": isMonitoringProcessesRAM = false
            default: break
            }
        }
        startTimer()
        if visible { sample() }
    }

    private func applyPreferences() {
        warningThreshold = preferences.warningThreshold
        criticalThreshold = preferences.criticalThreshold
    }

    private func startTimer() {
        guard !isSleeping else { return }
        let interval = visiblePopovers.isEmpty ? preferences.backgroundInterval : preferences.foregroundInterval
        guard interval != timerInterval else { return }
        timer?.invalidate()
        timerInterval = interval
        let nextTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.sample() }
        nextTimer.tolerance = min(0.5, interval * 0.1)
        RunLoop.main.add(nextTimer, forMode: .common)
        timer = nextTimer
    }

    private func sample() {
        // All scheduling and UI state is read on the main thread; the worker receives a fixed request.
        guard !isSleeping, !sampleInFlight else { return }
        sampleInFlight = true
        let now = ProcessInfo.processInfo.systemUptime
        let timestamp = Date()
        func isDue(_ last: TimeInterval?, interval: TimeInterval) -> Bool {
            last.map { now - $0 >= interval } ?? true
        }
        let readCPU = isMonitoringProcessesCPU && isDue(lastCPUProcessRead, interval: preferences.processInterval)
        let readRAM = isMonitoringProcessesRAM && isDue(lastRAMProcessRead, interval: preferences.processInterval)
        let readTemperature = isMonitoringTemperature && isDue(lastTemperatureRead, interval: preferences.temperatureInterval)
        let cpuGeneration = cpuProcessGeneration, ramGeneration = ramProcessGeneration
        let resetCPU = readCPU && sampledCPUProcessGeneration != cpuGeneration
        if readCPU {
            lastCPUProcessRead = now
            sampledCPUProcessGeneration = cpuGeneration
        }
        if readRAM { lastRAMProcessRead = now }
        if readTemperature { lastTemperatureRead = now }
        let monitor = self.monitor
        monitorQueue.async { [weak self, monitor] in
            autoreleasepool {
                monitor.update()
                let cpu = monitor.cpuStats().average
                let memory = monitor.memoryUsage()
                let gpu = monitor.gpuUsage()
                if resetCPU { monitor.resetProcessCPUHistory() }
                let processesCPU = readCPU ? ProcessUsage.decode(monitor.topProcessesByCPU() as NSArray) : nil
                let processesRAM = readRAM ? ProcessUsage.decode(monitor.topProcessesByRAM() as NSArray) : nil
                let temperature = readTemperature ? SensorReader.shared.cpuTemperature() : nil
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.sampleInFlight = false
                    guard !self.isSleeping else { return }
                    // A whole sample causes one dashboard invalidation, rather than one per property.
                    if !self.visiblePopovers.isEmpty { self.objectWillChange.send() }
                    self.cpuUser = cpu.user
                    self.cpuSystem = cpu.system
                    self.cpuIdle = cpu.idle
                    self.cpuUsage = cpu.total
                    self.cpuHistory.append(cpu.total, timestamp: timestamp)
                    self.memoryUsedBytes = memory.usedBytes
                    self.memoryPercent = memory.usedPercent
                    self.memoryTotalBytes = memory.totalBytes
                    self.memoryHistory.append(memory.usedPercent, timestamp: timestamp)
                    self.gpuUtilization = gpu.utilization
                    self.gpuRenderUtilization = gpu.renderUtilization
                    self.gpuTilerUtilization = gpu.tilerUtilization
                    self.gpuANEUtilization = gpu.aneUtilization
                    self.gpuVramUsed = gpu.vramUsed
                    self.gpuVramTotal = gpu.vramTotal
                    self.gpuUtilHistory.append(gpu.utilization, timestamp: timestamp)
                    self.gpuRenderHistory.append(gpu.renderUtilization, timestamp: timestamp)
                    self.gpuTilerHistory.append(gpu.tilerUtilization, timestamp: timestamp)
                    self.gpuANEHistory.append(gpu.aneUtilization, timestamp: timestamp)
                    if self.isMonitoringProcessesCPU, cpuGeneration == self.cpuProcessGeneration, let processesCPU {
                        self.topProcessesByCPU = processesCPU
                    }
                    if self.isMonitoringProcessesRAM, ramGeneration == self.ramProcessGeneration, let processesRAM {
                        self.topProcessesByRAM = processesRAM
                    }
                    if self.isMonitoringTemperature, readTemperature { self.cpuTemperature = temperature }
                    self.menuBarMetrics.update(cpu: cpu.total, ram: memory.usedPercent, gpu: gpu.utilization)
                }
            }
        }
    }
}
