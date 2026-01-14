import SwiftUI
import UniformTypeIdentifiers

extension UTType {
  /// Custom UTType for OpenSCAD source files (.scad)
  /// Uses exportedAs to declare this app as the owner of the type
  static var scadSource: UTType {
    UTType(exportedAs: "org.openscad.scad", conformingTo: .sourceCode)
  }
}

struct ScadDocument: FileDocument {
  var text: String

  /// Supported types for reading - prioritize .scad files, fallback to plain text
  static var readableContentTypes: [UTType] { [.scadSource, .plainText] }

  /// Supported types for writing - prioritize .scad files, also support plain text
  static var writableContentTypes: [UTType] { [.scadSource, .plainText] }

  /// Default file extension when saving new documents
  static var defaultFileExtension: String { "scad" }

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

  /// Returns a snapshot of the document for saving
  /// This is used by the document system to determine if the document has changes
  func snapshot() -> String {
    return text
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
