import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack {
      Image(systemName: "cube.transparent")
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text("OpenSCAD App")
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
