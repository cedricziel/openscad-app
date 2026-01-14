import Combine
import Foundation

/// Supported export formats for OpenSCAD models
enum ExportFormat: String, CaseIterable, Identifiable {
  case stl = "stl"
  case obj = "obj"
  case off = "off"
  case amf = "amf"
  case threemf = "3mf"
  case dxf = "dxf"
  case svg = "svg"
  case csg = "csg"
  case png = "png"

  var id: String { rawValue }

  /// Display name for the format
  var displayName: String {
    switch self {
    case .stl: return "STL (Stereolithography)"
    case .obj: return "OBJ (Wavefront)"
    case .off: return "OFF (Object File Format)"
    case .amf: return "AMF (Additive Manufacturing)"
    case .threemf: return "3MF (3D Manufacturing)"
    case .dxf: return "DXF (2D Drawing)"
    case .svg: return "SVG (2D Vector)"
    case .csg: return "CSG (OpenSCAD CSG)"
    case .png: return "PNG (Image)"
    }
  }

  /// File extension for the format
  var fileExtension: String {
    rawValue
  }

  /// Whether this is a 3D format suitable for 3D printing
  var is3DFormat: Bool {
    switch self {
    case .stl, .obj, .off, .amf, .threemf:
      return true
    case .dxf, .svg, .csg, .png:
      return false
    }
  }

  /// Allowed file types for save panel
  var allowedContentTypes: [String] {
    [rawValue]
  }
}

enum OpenSCADError: LocalizedError {
  case notInstalled
  case executionFailed(String)
  case outputFileNotFound
  case invalidOutput
  case exportFailed(String)

  var errorDescription: String? {
    switch self {
    case .notInstalled:
      return "OpenSCAD is not installed. Please install OpenSCAD from https://openscad.org"
    case .executionFailed(let message):
      return "OpenSCAD execution failed: \(message)"
    case .outputFileNotFound:
      return "Output file was not generated"
    case .invalidOutput:
      return "Invalid output from OpenSCAD"
    case .exportFailed(let message):
      return "Export failed: \(message)"
    }
  }
}

@MainActor
class OpenSCADService: ObservableObject {
  @Published var outputData: Data?
  @Published var lastError: String?
  @Published var isOpenSCADAvailable: Bool = false

  private let openSCADPaths: [String] = [
    "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD",
    "/usr/local/bin/openscad",
    "/opt/homebrew/bin/openscad",
    "/usr/bin/openscad",
  ]

  private var openSCADPath: String?

  init() {
    openSCADPath = findOpenSCAD()
    isOpenSCADAvailable = openSCADPath != nil
  }

  private func findOpenSCAD() -> String? {
    for path in openSCADPaths {
      if FileManager.default.isExecutableFile(atPath: path) {
        return path
      }
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = ["openscad"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    do {
      try process.run()
      process.waitUntilExit()

      if process.terminationStatus == 0 {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(
          in: .whitespacesAndNewlines),
          !path.isEmpty
        {
          return path
        }
      }
    } catch {
      // Silently fail
    }

    return nil
  }

  func execute(script: String) async throws {
    guard let executablePath = openSCADPath else {
      throw OpenSCADError.notInstalled
    }

    let tempDir = FileManager.default.temporaryDirectory
    let inputURL = tempDir.appendingPathComponent("input_\(UUID().uuidString).scad")
    let outputURL = tempDir.appendingPathComponent("output_\(UUID().uuidString).stl")

    defer {
      try? FileManager.default.removeItem(at: inputURL)
      try? FileManager.default.removeItem(at: outputURL)
    }

    try script.write(to: inputURL, atomically: true, encoding: .utf8)

    let result = try await runOpenSCAD(
      executablePath: executablePath,
      inputPath: inputURL.path,
      outputPath: outputURL.path
    )

    if !result.success {
      throw OpenSCADError.executionFailed(result.errorOutput)
    }

    guard FileManager.default.fileExists(atPath: outputURL.path) else {
      throw OpenSCADError.outputFileNotFound
    }

    let data = try Data(contentsOf: outputURL)
    self.outputData = data
  }

  private func runOpenSCAD(executablePath: String, inputPath: String, outputPath: String)
    async throws -> (success: Bool, errorOutput: String)
  {
    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["-o", outputPath, inputPath]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        do {
          try process.run()
          process.waitUntilExit()

          let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
          let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

          let success = process.terminationStatus == 0
          continuation.resume(returning: (success, errorOutput))
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  func clearOutput() {
    outputData = nil
    lastError = nil
  }

  /// Export the OpenSCAD script to a file in the specified format
  /// - Parameters:
  ///   - script: The OpenSCAD script content
  ///   - destinationURL: The URL where the exported file should be saved
  ///   - format: The export format to use
  func export(script: String, to destinationURL: URL, format: ExportFormat) async throws {
    guard let executablePath = openSCADPath else {
      throw OpenSCADError.notInstalled
    }

    let tempDir = FileManager.default.temporaryDirectory
    let inputURL = tempDir.appendingPathComponent("export_input_\(UUID().uuidString).scad")
    let tempOutputURL = tempDir.appendingPathComponent(
      "export_output_\(UUID().uuidString).\(format.fileExtension)")

    defer {
      try? FileManager.default.removeItem(at: inputURL)
      try? FileManager.default.removeItem(at: tempOutputURL)
    }

    try script.write(to: inputURL, atomically: true, encoding: .utf8)

    let result = try await runOpenSCAD(
      executablePath: executablePath,
      inputPath: inputURL.path,
      outputPath: tempOutputURL.path
    )

    if !result.success {
      throw OpenSCADError.exportFailed(result.errorOutput)
    }

    guard FileManager.default.fileExists(atPath: tempOutputURL.path) else {
      throw OpenSCADError.outputFileNotFound
    }

    // Copy to destination, removing existing file if necessary
    if FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.removeItem(at: destinationURL)
    }
    try FileManager.default.copyItem(at: tempOutputURL, to: destinationURL)
  }
}
