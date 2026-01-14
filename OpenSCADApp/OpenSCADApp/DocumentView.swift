import AppKit
import SwiftUI

struct DocumentView: View {
  @Binding var document: ScadDocument
  @StateObject private var openSCADService = OpenSCADService()
  @State private var isExecuting = false
  @State private var isExporting = false
  @State private var showError = false
  @State private var errorMessage = ""
  @State private var splitRatio: CGFloat = 0.5
  @State private var showExportFormatPicker = false
  @State private var selectedExportFormat: ExportFormat = .stl

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

        Menu {
          ForEach(ExportFormat.printableFormats) { format in
            Button(format.displayName) {
              exportToFormat(format)
            }
          }

          Divider()

          ForEach(ExportFormat.allCases.filter { !$0.is3DPrintable }) { format in
            Button(format.displayName) {
              exportToFormat(format)
            }
          }
        } label: {
          Label("Export", systemImage: "square.and.arrow.up")
        }
        .disabled(isExecuting || isExporting || !openSCADService.isOpenSCADAvailable)
        .help(
          openSCADService.isOpenSCADAvailable
            ? "Export to 3D printable format (⌘E)" : "OpenSCAD not found")
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
    .onReceive(NotificationCenter.default.publisher(for: .exportToFormat)) { notification in
      if let format = notification.object as? ExportFormat {
        exportToFormat(format)
      }
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

  private func exportToFormat(_ format: ExportFormat) {
    guard !isExporting else { return }
    guard openSCADService.isOpenSCADAvailable else {
      errorMessage = "OpenSCAD is not installed or not found in the expected locations."
      showError = true
      return
    }

    // Show save panel
    let savePanel = NSSavePanel()
    savePanel.title = "Export \(format.displayName)"
    savePanel.nameFieldStringValue = "Untitled.\(format.fileExtension)"
    savePanel.allowedContentTypes = [.init(filenameExtension: format.fileExtension) ?? .data]
    savePanel.canCreateDirectories = true

    savePanel.begin { response in
      guard response == .OK, let url = savePanel.url else { return }

      isExporting = true

      Task {
        do {
          try await openSCADService.export(script: document.text, format: format, to: url)
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
          isExporting = false
        }
      }
    }
  }
}

#Preview {
  DocumentView(document: .constant(ScadDocument()))
}
