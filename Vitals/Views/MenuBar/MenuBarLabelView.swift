import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var vm: SystemViewModel
    let module: String  // "CPU" или "RAM"
    
    var body: some View {
        switch module {
        case "RAM": Mini(title: "RAM", value: String(format: "%.0f%%", vm.memoryPercent))
        case "GPU": Mini(title: "GPU", value: String(format: "%.0f%%", vm.gpuUtilization))
        default:    Mini(title: "CPU", value: String(format: "%.0f%%", vm.cpuUsage))
        }
    }
}
