nonisolated enum MetricHelpTopic: CaseIterable, Identifiable {
    case memorySwap, memoryPressure
    case gpuUtilization, gpuRenderer, gpuTiler, gpuNeuralEngine, gpuMemory

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .memorySwap: "memory_swap_used"
        case .memoryPressure: "memory_pressure"
        case .gpuUtilization: "block_chart_gpu_util"
        case .gpuRenderer: "block_chart_gpu_render"
        case .gpuTiler: "block_chart_gpu_tiler"
        case .gpuNeuralEngine: "block_chart_gpu_ane"
        case .gpuMemory: "gpu_memory_title"
        }
    }

    var explanationKey: String {
        switch self {
        case .memorySwap: "memory_swap_help"
        case .memoryPressure: "memory_pressure_help"
        case .gpuUtilization: "gpu_utilization_help"
        case .gpuRenderer: "gpu_renderer_help"
        case .gpuTiler: "gpu_tiler_help"
        case .gpuNeuralEngine: "gpu_neural_engine_help"
        case .gpuMemory: "gpu_memory_help"
        }
    }

}
