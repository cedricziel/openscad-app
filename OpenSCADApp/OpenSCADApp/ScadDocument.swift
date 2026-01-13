import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var scadSource: UTType {
        UTType(importedAs: "org.openscad.scad", conformingTo: .sourceCode)
    }
}

struct ScadDocument: FileDocument {
    var text: String

    static var readableContentTypes: [UTType] { [.scadSource, .plainText] }
    static var writableContentTypes: [UTType] { [.scadSource, .plainText] }

    init(text: String = defaultScadContent) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }

    private static var defaultScadContent: String {
        """
        // OpenSCAD Script
        // Create your 3D design here

        // Example: A simple cube
        cube([10, 10, 10]);
        """
    }
}
