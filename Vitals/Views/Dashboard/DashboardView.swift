//
//  DashboardView.swift
//  Vitals
//
//  Created by Алексей on 6/29/26.
//

import SwiftUI

struct DashboardView: View {
    
    var blocks: [DashboardBlock]
    @ObservedObject var config: DashboardConfig
    @State private var showingSettingsFor: BlockContent? = nil
    @State private var isEditing: Bool = false
    @Environment(\.openSettings) var openSettings
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                Button { isEditing.toggle() } label: {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                }
                .buttonStyle(.plain)
            }
            .padding(10)

            VStack {
                ForEach(config.order, id: \.self) { id in
                    if let block = blocks.first(where: { $0.id == id }) {
                        VStack(spacing: 0) {
                            if isEditing {
                                HStack {
                                    Toggle(block.title, isOn:
                                        Binding(
                                            get: { config.isVisible(id: id) },
                                            set: { config.setVisible(id: id, $0) }
                                        ))
                                        .toggleStyle(.switch)
                                    Spacer()
                                    Button { config.moveUp(id: id) } label: { Image(systemName: "chevron.up") }
                                    Button { config.moveDown(id: id) } label: { Image(systemName: "chevron.down") }
                                    if block.hasSettings {
                                        Button { showingSettingsFor = block.content } label: {
                                                Image(systemName: "gear")
                                            }
                                            .popover(isPresented: Binding(
                                                get: { showingSettingsFor?.id == block.content.id },
                                                set: { if !$0 { showingSettingsFor = nil } }
                                            )) {
                                                settingsView(for: block.content)
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            if config.isVisible(id: id) {
                                blockView(for: block.content)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func blockView(for content: BlockContent) -> some View {
        switch content {
        case .cpuIndicators: CPUIndicatorsView()
        case .cpuDetails: CPUDetailsView()
        case .cpuChart(let namespace): ChartView(namespace: namespace, history: \.cpuHistory)
        case .cpuProcesses: CPUProcessesView()
        case .gpuIndicators: GPUIndicatorsView()
        case .gpuDetails: GPUDetailsView()
        case .gpuChartUtl(let namespace): ChartView(namespace: namespace,history: \.gpuUtilHistory)
        case .gpuChartRender(let namespace): ChartView( namespace: namespace, history: \.gpuRenderHistory)
        case .gpuChartTiler(let namespace): ChartView(namespace: namespace, history: \.gpuTilerHistory)
        case .gpuChartANE(let namespace): ChartView(namespace: namespace, history: \.gpuANEHistory)
        case .ramIndicators: RAMIndicatorsView()
        case .ramDetails: RAMDetailsView()
        case .ramChart(let namespace): ChartView(namespace: namespace, history: \.memoryHistory)
        case .ramProcesses: RAMProcessesView()
        }
    }
    
    @ViewBuilder
    func settingsView(for content: BlockContent) -> some View {
        switch content {
        case .cpuChart(let namespace):
            ChartSettingsView(namespace: namespace)
        case .gpuChartUtl(let namespace):
            ChartSettingsView(namespace: namespace)
        case .gpuChartRender(let namespace):
            ChartSettingsView(namespace: namespace)
        case .gpuChartTiler(let namespace):
            ChartSettingsView(namespace: namespace)
        case .gpuChartANE(let namespace):
            ChartSettingsView(namespace: namespace)
        case .ramChart(let namespace):
            ChartSettingsView(namespace: namespace)
        default:
            EmptyView()
        }
    }
}
