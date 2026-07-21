import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 48))
            Text("InceptLaunch")
                .font(.largeTitle)
            Text("Launchpad replacement prototype")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}
