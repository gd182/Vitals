import Combine

class SystemViewModel: ObservableObject {
    @Published var cpuUsage: Float = 0.0
    @Published var memoryUsedBytes: UInt64 = 0
    @Published var memoryPercent: Float = 0.0
    @Published var cpuUser: Float = 0.0
    @Published var cpuSystem: Float = 0.0
    @Published var cpuIdle: Float = 0.0
    @Published var cpuHistory = HistoryData()
    @Published var memoryHistory = HistoryData()
    @Published var gpuUtilHistory = HistoryData()
    @Published var gpuRenderHistory = HistoryData()
    @Published var gpuTilerHistory = HistoryData()
    @Published var gpuANEHistory = HistoryData()
    @Published var topProcessesByCPU: [[String: Any]] = []
    @Published var topProcessesByRAM: [[String: Any]] = []
    @Published var cpuTemperature: Float = 0.0
    @Published var memoryTotalBytes: UInt64 = 0
    @Published var gpuUtilization: Float = 0.0
    @Published var gpuRenderUtilization: Float = 0.0
    @Published var gpuTilerUtilization: Float = 0.0
    @Published var gpuANEUtilization: Float = 0.0
    @Published var gpuVramUsed: UInt64 = 0
    @Published var gpuVramTotal: UInt64 = 0
    var isMonitoringProcessesCPU = false
    var isMonitoringProcessesGPU = false
    var isMonitoringProcessesRAM = false
    
    
    private let monitor = SystemMonitor()
    private var timer: Timer?
    private var intervalObserver: NSObjectProtocol?


    
    init() {
        intervalObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let newInterval = UserDefaults.standard.double(forKey: "updateInterval")
            if newInterval > 0 {
                self?.startTimer(interval: newInterval)
            }
        }
        let interval = UserDefaults.standard.double(forKey: "updateInterval")
        startTimer(interval: interval > 0 ? interval : 1.0)
    }
    
    private func startTimer(interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.monitor.update()
            let stats = self?.monitor.cpuStats()
            DispatchQueue.main.async {
                self?.cpuUser = stats?.average.user ?? 0
                self?.cpuSystem = stats?.average.system ?? 0
                self?.cpuIdle = stats?.average.idle ?? 0
                self?.cpuUsage = stats?.average.total ?? 0
                self?.cpuHistory.append(Float(stats?.average.total ?? 0))
                if self?.isMonitoringProcessesCPU == true {
                    let rawProcCPU = self?.monitor.topProcessesByCPU()
                    self?.topProcessesByCPU = rawProcCPU as? [[String: Any]] ?? []
                }
                if self?.isMonitoringProcessesRAM == true {
                    let rawProcRAM = self?.monitor.topProcessesByRAM()
                    self?.topProcessesByRAM = rawProcRAM as? [[String: Any]] ?? []
                }
                let memory = self?.monitor.memoryUsage()
                self?.memoryUsedBytes = memory?.usedBytes ?? 0
                self?.memoryPercent = memory?.usedPercent ?? 0
                self?.memoryHistory.append(Float(memory?.usedPercent ?? 0))
                self?.memoryTotalBytes = memory?.totalBytes ?? 0
                let gpu = self?.monitor.gpuUsage()
                self?.gpuUtilization = gpu?.utilization ?? 0
                self?.gpuRenderUtilization = gpu?.renderUtilization ?? 0
                self?.gpuTilerUtilization = gpu?.tilerUtilization ?? 0
                self?.gpuANEUtilization = gpu?.aneUtilization ?? 0
                self?.gpuVramUsed = gpu?.vramUsed ?? 0
                self?.gpuVramTotal = gpu?.vramTotal ?? 0
                self?.gpuUtilHistory.append(gpu?.utilization ?? 0)
                self?.gpuRenderHistory.append(gpu?.renderUtilization ?? 0)
                self?.gpuTilerHistory.append(gpu?.tilerUtilization ?? 0)
                self?.gpuANEHistory.append(gpu?.aneUtilization ?? 0)

                self?.cpuTemperature = SensorReader.shared.cpuTemperature() ?? 0
            }
        }
    }

}
