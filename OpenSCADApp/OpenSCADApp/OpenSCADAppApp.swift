import SwiftUI
import UniformTypeIdentifiers

@main
struct OpenSCADAppApp: App {
  var body: some Scene {
    DocumentGroup(newDocument: ScadDocument()) { file in
      DocumentView(document: file.$document)
    }
    .defaultSize(width: 1200, height: 800)
    .commands {
      CommandGroup(after: .newItem) {
        Button("Execute Script") {
          NotificationCenter.default.post(name: .executeScript, object: nil)
        }
        .keyboardShortcut("r", modifiers: .command)
      }
      // Standard save commands are automatically provided by DocumentGroup
      // The following adds explicit Save As functionality
      CommandGroup(after: .saveItem) {
        Button("Save As...") {
          NotificationCenter.default.post(name: .saveDocumentAs, object: nil)
        }
        .keyboardShortcut("s", modifiers: [.command, .shift])
      }
      CommandGroup(replacing: .importExport) {
        Menu("Export As...") {
          Section("3D Formats") {
            ForEach(ExportFormat.allCases.filter { $0.is3DFormat }) { format in
              Button(format.displayName) {
                NotificationCenter.default.post(
                  name: .exportScript, object: format)
              }
            }
          }
          Section("Other Formats") {
            ForEach(ExportFormat.allCases.filter { !$0.is3DFormat }) { format in
              Button(format.displayName) {
                NotificationCenter.default.post(
                  name: .exportScript, object: format)
              }
            }
          }
        }
        Button("Export to STL...") {
          NotificationCenter.default.post(name: .exportScript, object: ExportFormat.stl)
        }
        .keyboardShortcut("e", modifiers: .command)
      }
    }
  }
}

extension Notification.Name {
  static let executeScript = Notification.Name("executeScript")
  static let exportScript = Notification.Name("exportScript")
  static let saveDocumentAs = Notification.Name("saveDocumentAs")
}
