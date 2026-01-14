import SwiftUI

@main
struct OpenSCADAppApp: App {
  var body: some Scene {
    DocumentGroup(newDocument: ScadDocument()) { file in
      DocumentView(document: file.$document)
    }
    .commands {
      CommandGroup(after: .newItem) {
        Button("Execute Script") {
          NotificationCenter.default.post(name: .executeScript, object: nil)
        }
        .keyboardShortcut("r", modifiers: .command)

        Divider()

        Menu("Export As...") {
          ForEach(ExportFormat.printableFormats) { format in
            Button(format.displayName) {
              NotificationCenter.default.post(
                name: .exportToFormat,
                object: format
              )
            }
          }

          Divider()

          ForEach(ExportFormat.allCases.filter { !$0.is3DPrintable }) { format in
            Button(format.displayName) {
              NotificationCenter.default.post(
                name: .exportToFormat,
                object: format
              )
            }
          }
        }

        Button("Export to STL...") {
          NotificationCenter.default.post(
            name: .exportToFormat,
            object: ExportFormat.stl
          )
        }
        .keyboardShortcut("e", modifiers: .command)
      }
    }
  }
}

extension Notification.Name {
  static let executeScript = Notification.Name("executeScript")
  static let exportToFormat = Notification.Name("exportToFormat")
}
