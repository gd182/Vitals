import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var metrics: MenuBarMetrics
    let module: String  // "CPU" или "RAM"
    
    var body: some View {
        switch module {
        case "RAM": Mini(title: "RAM", value: "\(metrics.ram)%")
        case "GPU": Mini(title: "GPU", value: "\(metrics.gpu)%")
        default:    Mini(title: "CPU", value: "\(metrics.cpu)%")
        }
    }
}
