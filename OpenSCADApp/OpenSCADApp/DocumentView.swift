import SwiftUI

struct DocumentView: View {
  @Binding var document: ScadDocument
  @StateObject private var openSCADService = OpenSCADService()
  @State private var isExecuting = false
  @State private var showError = false
  @State private var errorMessage = ""
  @State private var splitRatio: CGFloat = 0.5

  var body: some View {
    GeometryReader { geometry in
      HSplitView {
        VStack(spacing: 0) {
          editorHeader
          CodeEditorView(text: $document.text)
        }
        .frame(minWidth: 300)

        VStack(spacing: 0) {
          viewerHeader
          ModelViewer(modelData: openSCADService.outputData, isLoading: isExecuting)
        }
        .frame(minWidth: 300)
      }
    }
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button(action: executeScript) {
          Label("Execute", systemImage: "play.fill")
        }
        .disabled(isExecuting || !openSCADService.isOpenSCADAvailable)
        .help(openSCADService.isOpenSCADAvailable ? "Execute script (⌘R)" : "OpenSCAD not found")
      }
    }
    .alert("Error", isPresented: $showError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage)
    }
    .onReceive(NotificationCenter.default.publisher(for: .executeScript)) { _ in
      executeScript()
    }
  }

  private var editorHeader: some View {
    HStack {
      Label("Script Editor", systemImage: "doc.text")
        .font(.headline)
      Spacer()
      if !openSCADService.isOpenSCADAvailable {
        Label("OpenSCAD not found", systemImage: "exclamationmark.triangle")
          .foregroundColor(.orange)
          .font(.caption)
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .background(Color(NSColor.controlBackgroundColor))
  }

  private var viewerHeader: some View {
    HStack {
      Label("3D Preview", systemImage: "cube.transparent")
        .font(.headline)
      Spacer()
      if isExecuting {
        ProgressView()
          .scaleEffect(0.7)
        Text("Rendering...")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .background(Color(NSColor.controlBackgroundColor))
  }

  private func executeScript() {
    guard !isExecuting else { return }
    guard openSCADService.isOpenSCADAvailable else {
      errorMessage = "OpenSCAD is not installed or not found in the expected locations."
      showError = true
      return
    }

    isExecuting = true

    Task {
      do {
        try await openSCADService.execute(script: document.text)
      } catch let error as OpenSCADError {
        await MainActor.run {
          errorMessage = error.localizedDescription
          showError = true
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          showError = true
        }
      }

      await MainActor.run {
        isExecuting = false
      }
    }
  }
}

#Preview {
  DocumentView(document: .constant(ScadDocument()))
}
