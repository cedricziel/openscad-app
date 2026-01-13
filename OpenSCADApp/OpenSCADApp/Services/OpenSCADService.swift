import Foundation
import Combine

enum OpenSCADError: LocalizedError {
    case notInstalled
    case executionFailed(String)
    case outputFileNotFound
    case invalidOutput

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
        "/usr/bin/openscad"
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
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
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

    private func runOpenSCAD(executablePath: String, inputPath: String, outputPath: String) async throws -> (success: Bool, errorOutput: String) {
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
}
