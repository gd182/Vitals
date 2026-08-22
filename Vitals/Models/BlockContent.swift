//
//  BlockContent.swift
//  Vitals
//
//  Created by Алексей on 8/20/26.
//

enum BlockContent {
    case cpuIndicators
    case cpuDetails
    case cpuChart(namespace: String)
    case cpuProcesses
    case gpuIndicators
    case gpuDetails
    case gpuChartUtl(namespace: String)
    case gpuChartRender(namespace: String)
    case gpuChartTiler(namespace: String)
    case gpuChartANE(namespace: String)
    case ramIndicators
    case ramDetails
    case ramChart(namespace: String)
    case ramProcesses
}

extension BlockContent: Identifiable {
    var id: String {
        switch self {
        case .cpuIndicators: return "cpuIndicators"
        case .cpuDetails:    return "cpuDetails"
        case .cpuChart(let ns): return "cpuChart_\(ns)"
        case .cpuProcesses:  return "cpuProcesses"
        case .gpuIndicators: return "gpuIndicators"
        case .gpuDetails:    return "gpuDetails"
        case .gpuChartUtl(namespace: let ns): return "gpuChartUtl_\(ns)"
        case .gpuChartRender(namespace: let ns): return "gpuChartRender_\(ns)"
        case .gpuChartTiler(namespace: let ns): return "gpuChartTiler_\(ns)"
        case .gpuChartANE(namespace: let ns): return "gpuChartANE_\(ns)"
        case .ramIndicators: return "ramIndicators"
        case .ramDetails:    return "ramDetails"
        case .ramChart(let ns): return "ramChart_\(ns)"
        case .ramProcesses:  return "ramProcesses"
        }
    }
}
