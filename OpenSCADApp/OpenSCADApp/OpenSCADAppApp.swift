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
            }
        }
    }
}

extension Notification.Name {
    static let executeScript = Notification.Name("executeScript")
}
