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
    var onSizeChange: ((CGSize) -> Void)? = nil
    @State private var showingSettingsFor: BlockContent? = nil
    @State private var isEditing: Bool = false
    @Environment(\.openSettings) var openSettings
    
    @AppStorage("panelWidth") private var panelWidth: Double = 360
    @AppStorage("panelCompact") private var compact = true
    @AppStorage("panelSectionTitles") private var sectionTitles = true
    @State private var contentHeight: CGFloat = 480

    private var headerHeight: CGFloat { compact ? 36 : 52 }
    private var maximumHeight: CGFloat {
        min(600, max(240, (NSScreen.main?.visibleFrame.height ?? 800) - 100))
    }
    private var panelSize: CGSize {
        CGSize(width: panelWidth == 420 ? 420 : 360,
               height: headerHeight + 1 + min(contentHeight, maximumHeight - headerHeight - 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(config.namespace).font(.system(size: compact ? 13 : 15, weight: .semibold))
                Spacer()
                if isEditing {
                    Button {
                        config.reset(ids: blocks.map(\.id))
                    } label: { Image(systemName: "arrow.counterclockwise") }
                    .help("panel_reset")
                }
                Button {
                    isEditing.toggle()
                } label: { Image(systemName: isEditing ? "checkmark" : "slider.horizontal.3") }
                .help(isEditing ? LocalizedStringKey("panel_done") : LocalizedStringKey("panel_customize"))
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                } label: { Image(systemName: "gearshape") }
                .help("settings_tab_general")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .padding(.horizontal, compact ? 12 : 16)
            .frame(height: headerHeight)
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(config.order, id: \.self) { id in
                        if let block = blocks.first(where: { $0.id == id }),
                           isEditing || config.isVisible(id: id) {
                            VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                                if isEditing || sectionTitles {
                                HStack(spacing: 8) {
                                    if isEditing {
                                        Toggle(block.title, isOn: Binding(
                                            get: { config.isVisible(id: id) },
                                            set: { config.setVisible(id: id, $0) }
                                        ))
                                        .toggleStyle(.checkbox)
                                    } else {
                                        Text(block.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 4)
                                    if isEditing {
                                        Button { config.moveUp(id: id) } label: { Image(systemName: "chevron.up") }
                                            .disabled(config.order.first == id).help("panel_move_up")
                                        Button { config.moveDown(id: id) } label: { Image(systemName: "chevron.down") }
                                            .disabled(config.order.last == id).help("panel_move_down")
                                    }
                                    if block.hasSettings {
                                        Button { showingSettingsFor = block.content } label: { Image(systemName: "gearshape") }
                                            .help("panel_chart_settings")
                                            .popover(isPresented: Binding(
                                                get: { showingSettingsFor?.id == block.content.id },
                                                set: { if !$0 { showingSettingsFor = nil } }
                                            )) { settingsView(for: block.content) }
                                    }
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                                }
                                if config.isVisible(id: id) { blockView(for: block.content) }
                            }
                            .padding(.horizontal, compact ? 12 : 16)
                            .padding(.vertical, compact ? 6 : 16)
                            Divider()
                        }
                    }
                    if !isEditing && !blocks.contains(where: { config.isVisible(id: $0.id) }) {
                        Text("panel_empty").foregroundStyle(.secondary).padding(24)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height in
                    let rounded = max(1, height.rounded(.up))
                    if contentHeight != rounded { contentHeight = rounded }
                }
            }
            .frame(height: min(contentHeight, maximumHeight - headerHeight - 1))
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .onChange(of: panelSize, initial: true) { _, size in onSizeChange?(size) }
        .background(Color(nsColor: .windowBackgroundColor))
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
