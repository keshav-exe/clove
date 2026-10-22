import SwiftUI

struct HomeRunningCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let running = model.running
        HomeCard(
            title: "Running Now",
            symbolName: "waveform.path.ecg",
            value: (running.processes.value?.count ?? 0).formatted(),
            caption: "agents and servers",
            destination: .running
        ) {
            ForEach(RunningProcess.Kind.allCases, id: \.self) { kind in
                HomeRow(label: kind.title, value: running.items(of: kind).count.formatted(), destination: .running)
            }
        }
    }
}
