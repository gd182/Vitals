import Combine
import Foundation
import AppKit

@MainActor
final class MenuBarMetric: ObservableObject {
    @Published private(set) var value: Int = 0
    func update(from newValue: Float) {
        let rounded = newValue.rounded()
        let nextValue: Int = rounded.isFinite
            ? (Int(exactly: rounded) ?? 0)
            : 0
        guard value != nextValue else {
            return
        }
        value = nextValue
    }
}

@MainActor
final class MenuBarMetrics {
    let cpu = MenuBarMetric()
    let ram = MenuBarMetric()
    let gpu = MenuBarMetric()

    func update(cpu: Float, ram: Float, gpu: Float) {
        self.cpu.update(from: cpu)
        self.ram.update(from: ram)
        self.gpu.update(from: gpu)
    }
}

@MainActor
final class SystemViewModel: @MainActor ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    let menuBarMetrics = MenuBarMetrics()
    private(set) var cpuUsage: Float = 0
    private(set) var memoryUsedBytes: UInt64 = 0
    private(set) var memoryPercent: Float = 0
    private(set) var swapTotalBytes: UInt64? = nil
    private(set) var swapUsedBytes: UInt64? = nil
    private(set) var memoryPressure: ObjCMemoryPressure = .unknown
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
    private(set) var cpuProcessState: ProcessListState = .inactive
    private(set) var topProcessesByRAM: [ProcessUsage] = []
    private(set) var ramProcessState: ProcessListState = .inactive
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
    private var processSampleRequested: Bool = false
    private var cpuWarmupTimer: Timer? = nil

    private func resetWarmupTimer() {
        cpuWarmupTimer?.invalidate()
        cpuWarmupTimer = nil
    }

    private func scheduleCPUWarmup(generation: Int) {
        resetWarmupTimer()

        let timer = Timer(
            timeInterval: 0.5,
            repeats: false
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self,
                    self.isMonitoringProcessesCPU,
                    !self.isSleeping,
                    generation == self.cpuProcessGeneration,
                    self.cpuProcessState == .loading
                else {
                    return
                }

                self.cpuWarmupTimer = nil
                self.requestProcessSample()
            }
        }

        cpuWarmupTimer = timer

        RunLoop.main.add(timer, forMode: .common)
    }

    private func requestProcessSample() {
        guard !isSleeping, !sampleInFlight else {
            processSampleRequested = true
            return
        }
        processSampleRequested = false
        sample()
    }

    var isMonitoringProcessesCPU = false {
        didSet {
            guard oldValue != isMonitoringProcessesCPU else { return }
            resetWarmupTimer()
            objectWillChange.send()
            cpuProcessState = isMonitoringProcessesCPU == true
                ? .loading
                : .inactive
            lastCPUProcessRead = nil
            cpuProcessGeneration += 1
            if !isMonitoringProcessesCPU {
                topProcessesByCPU = []
                monitorWorker.perform { monitor in monitor.resetProcessCPUHistory() }
            } else {
                requestProcessSample()
            }
        }
    }
    var isMonitoringProcessesRAM = false {
        didSet {
            guard oldValue != isMonitoringProcessesRAM else { return }
            objectWillChange.send()
            ramProcessState = isMonitoringProcessesRAM == true
                ? .loading
                : .inactive
            lastRAMProcessRead = nil
            ramProcessGeneration += 1
            if !isMonitoringProcessesRAM {
                topProcessesByRAM = []
            } else {
                requestProcessSample()
            }
        }
    }
    var isMonitoringTemperature = false {
        didSet { if !isMonitoringTemperature { lastTemperatureRead = nil } }
    }

    private let monitorWorker = MonitorWorker()
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
    private var ramDetailsGeneration = 0
    private var sampledCPUProcessGeneration = -1

    private func invalidateRAMDetails() {
        ramDetailsGeneration += 1
        if swapTotalBytes != nil || swapUsedBytes != nil || memoryPressure != .unknown {
            objectWillChange.send()
        }
        swapTotalBytes = nil
        swapUsedBytes = nil
        memoryPressure = .unknown
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferences = MonitoringPreferences(defaults: defaults)
        applyPreferences()
        // These observers deliver on .main; preserve synchronous actor-isolated handling.
        intervalObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let next = MonitoringPreferences(defaults: self.defaults)
                guard next != self.preferences else { return }
                let blockChanged = next.ramDetailsVisible != self.preferences.ramDetailsVisible
                let swapChanged = blockChanged || next.ramShowSwap != self.preferences.ramShowSwap
                let pressureChanged = blockChanged || next.ramShowMemoryPressure != self.preferences.ramShowMemoryPressure
                self.objectWillChange.send()
                self.preferences = next
                if swapChanged || pressureChanged {
                    self.ramDetailsGeneration += 1
                    if swapChanged {
                        self.swapTotalBytes = nil
                        self.swapUsedBytes = nil
                    }
                    if pressureChanged { self.memoryPressure = .unknown }
                }
                self.applyPreferences()
                self.startTimer()
                if (swapChanged || pressureChanged), self.visiblePopovers.contains("RAM"),
                   next.ramDetailsVisible, next.ramShowSwap || next.ramShowMemoryPressure {
                    self.requestProcessSample()
                }
            }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        sleepObservers.append(workspace.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isSleeping = true
                self?.invalidateRAMDetails()
                self?.timer?.invalidate()
                self?.resetWarmupTimer()
                self?.timer = nil
                self?.timerInterval = nil
            }
        })
        sleepObservers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else {
                    return
                }
                self.isSleeping = false
                self.lastCPUProcessRead = nil
                self.lastRAMProcessRead = nil
                self.lastTemperatureRead = nil
                self.cpuProcessGeneration += 1
                if self.isMonitoringProcessesCPU {
                    self.objectWillChange.send()
                    self.cpuProcessState = .loading
                }
                self.startTimer()
                self.requestProcessSample()
            }
        })
        startTimer()
        sample()
    }

    deinit {
        timer?.invalidate()
        cpuWarmupTimer?.invalidate()
        if let intervalObserver { NotificationCenter.default.removeObserver(intervalObserver) }
        for observer in sleepObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    func setPopoverVisible(_ visible: Bool, module: String) {
        let wasVisible = visiblePopovers.contains(module)
        if visible { visiblePopovers.insert(module) } else { visiblePopovers.remove(module) }
        if module == "RAM", wasVisible != visible { invalidateRAMDetails() }
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
        if visible { requestProcessSample() }
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
        // Keep this timer on the main run loop for the isolation check below.
        let nextTimer = Timer(timeInterval: interval, repeats: true) {
            [weak self] _ in
                MainActor.assumeIsolated {
                    self?.sample()
                }
        }
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
        let cpuProcessInterval: TimeInterval = cpuProcessState == .loading
            ? min(0.5, preferences.processInterval)
            : preferences.processInterval
        let readCPU = isMonitoringProcessesCPU && isDue(lastCPUProcessRead, interval: cpuProcessInterval)
        let readRAM = isMonitoringProcessesRAM && isDue(lastRAMProcessRead, interval: preferences.processInterval)
        let readRAMDetails = visiblePopovers.contains("RAM") && preferences.ramDetailsVisible
        let readSwap = readRAMDetails && preferences.ramShowSwap
        let readPressure = readRAMDetails && preferences.ramShowMemoryPressure
        let ramDetailsGeneration = self.ramDetailsGeneration
        let readTemperature = isMonitoringTemperature && isDue(lastTemperatureRead, interval: preferences.temperatureInterval)
        let cpuGeneration = cpuProcessGeneration, ramGeneration = ramProcessGeneration
        let resetCPU = readCPU && sampledCPUProcessGeneration != cpuGeneration
        if readCPU {
            lastCPUProcessRead = now
            sampledCPUProcessGeneration = cpuGeneration
        }
        if readRAM { lastRAMProcessRead = now }
        if readTemperature { lastTemperatureRead = now }
        monitorWorker.perform { [weak self] monitor in
            autoreleasepool {
                monitor.update()
                let cpu = monitor.cpuStats().average
                let memory = monitor.memoryUsage()
                let memorySwap: ObjCSwapUsage? = readSwap ? monitor.swapUsage() : nil
                let pressure: ObjCMemoryPressure? = readPressure ? monitor.memoryPressure() : nil
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
                    // Visibility may have changed away and back while the worker was reading.
                    if ramDetailsGeneration == self.ramDetailsGeneration,
                       self.visiblePopovers.contains("RAM"), self.preferences.ramDetailsVisible {
                        if self.preferences.ramShowSwap, let memorySwap {
                            if memorySwap.available.boolValue {
                                swapTotalBytes = memorySwap.totalBytes
                                swapUsedBytes = memorySwap.usedBytes

                            } else {
                                swapTotalBytes = nil
                                swapUsedBytes = nil
                            }
                        }
                        if self.preferences.ramShowMemoryPressure, let pressure {
                            self.memoryPressure = pressure
                        }
                    }
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
                        if !resetCPU {
                            resetWarmupTimer()
                            cpuProcessState = .ready
                        } else {
                            self.scheduleCPUWarmup(generation: cpuGeneration)
                        }
                    }
                    if self.isMonitoringProcessesRAM, ramGeneration == self.ramProcessGeneration, let processesRAM {
                        self.topProcessesByRAM = processesRAM
                        ramProcessState = .ready
                    }
                    if self.isMonitoringTemperature, readTemperature { self.cpuTemperature = temperature }
                    self.menuBarMetrics.update(cpu: cpu.total, ram: memory.usedPercent, gpu: gpu.utilization)
                    if self.visiblePopovers.isEmpty
                        && !self.isMonitoringProcessesCPU
                        && !self.isMonitoringProcessesRAM {
                        processSampleRequested = false
                    } else {
                        if processSampleRequested {
                            self.requestProcessSample()
                        }
                    }
                }
            }
        }
    }
}
