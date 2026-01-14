import XCTest
@testable import OpenSCADApp

final class OpenSCADServiceTests: XCTestCase {

    @MainActor
    func testServiceInitialization() async throws {
        let service = OpenSCADService()

        // Service should initialize without crashing
        XCTAssertNotNil(service)

        // Output should be nil initially
        XCTAssertNil(service.outputData)
        XCTAssertNil(service.lastError)
    }

    @MainActor
    func testClearOutput() async throws {
        let service = OpenSCADService()

        service.clearOutput()

        XCTAssertNil(service.outputData)
        XCTAssertNil(service.lastError)
    }

    func testOpenSCADErrorDescriptions() {
        let notInstalledError = OpenSCADError.notInstalled
        XCTAssertNotNil(notInstalledError.errorDescription)
        XCTAssertTrue(notInstalledError.errorDescription!.contains("not installed"))

        let executionError = OpenSCADError.executionFailed("test error")
        XCTAssertNotNil(executionError.errorDescription)
        XCTAssertTrue(executionError.errorDescription!.contains("test error"))

        let outputError = OpenSCADError.outputFileNotFound
        XCTAssertNotNil(outputError.errorDescription)
        XCTAssertTrue(outputError.errorDescription!.contains("not generated"))

        let invalidError = OpenSCADError.invalidOutput
        XCTAssertNotNil(invalidError.errorDescription)
        XCTAssertTrue(invalidError.errorDescription!.contains("Invalid"))

        let exportError = OpenSCADError.exportFailed("export test error")
        XCTAssertNotNil(exportError.errorDescription)
        XCTAssertTrue(exportError.errorDescription!.contains("export test error"))
    }

    @MainActor
    func testExecuteWithoutOpenSCAD() async {
        let service = OpenSCADService()

        // If OpenSCAD is not available, execution should throw
        if !service.isOpenSCADAvailable {
            do {
                try await service.execute(script: "cube([10, 10, 10]);")
                XCTFail("Expected error when OpenSCAD is not installed")
            } catch let error as OpenSCADError {
                XCTAssertEqual(error.errorDescription, OpenSCADError.notInstalled.errorDescription)
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    @MainActor
    func testExportWithoutOpenSCAD() async {
        let service = OpenSCADService()

        // If OpenSCAD is not available, export should throw
        if !service.isOpenSCADAvailable {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_export.stl")
            do {
                try await service.export(script: "cube([10, 10, 10]);", to: tempURL, format: .stl)
                XCTFail("Expected error when OpenSCAD is not installed")
            } catch let error as OpenSCADError {
                XCTAssertEqual(error.errorDescription, OpenSCADError.notInstalled.errorDescription)
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
}

// MARK: - ExportFormat Tests

final class ExportFormatTests: XCTestCase {

    func testAllFormatsHaveDisplayNames() {
        for format in ExportFormat.allCases {
            XCTAssertFalse(format.displayName.isEmpty, "Format \(format.rawValue) should have a display name")
        }
    }

    func testAllFormatsHaveFileExtensions() {
        for format in ExportFormat.allCases {
            XCTAssertFalse(format.fileExtension.isEmpty, "Format \(format.rawValue) should have a file extension")
        }
    }

    func testFormatIdentifiers() {
        for format in ExportFormat.allCases {
            XCTAssertEqual(format.id, format.rawValue, "Format ID should equal raw value")
        }
    }

    func test3DFormats() {
        // These should be 3D formats
        XCTAssertTrue(ExportFormat.stl.is3DFormat)
        XCTAssertTrue(ExportFormat.obj.is3DFormat)
        XCTAssertTrue(ExportFormat.off.is3DFormat)
        XCTAssertTrue(ExportFormat.amf.is3DFormat)
        XCTAssertTrue(ExportFormat.threemf.is3DFormat)

        // These should NOT be 3D formats
        XCTAssertFalse(ExportFormat.dxf.is3DFormat)
        XCTAssertFalse(ExportFormat.svg.is3DFormat)
        XCTAssertFalse(ExportFormat.csg.is3DFormat)
        XCTAssertFalse(ExportFormat.png.is3DFormat)
    }

    func testSTLFormat() {
        let stl = ExportFormat.stl
        XCTAssertEqual(stl.rawValue, "stl")
        XCTAssertEqual(stl.fileExtension, "stl")
        XCTAssertTrue(stl.displayName.contains("STL"))
        XCTAssertTrue(stl.is3DFormat)
    }

    func testOBJFormat() {
        let obj = ExportFormat.obj
        XCTAssertEqual(obj.rawValue, "obj")
        XCTAssertEqual(obj.fileExtension, "obj")
        XCTAssertTrue(obj.displayName.contains("OBJ"))
        XCTAssertTrue(obj.is3DFormat)
    }

    func test3MFFormat() {
        let threemf = ExportFormat.threemf
        XCTAssertEqual(threemf.rawValue, "3mf")
        XCTAssertEqual(threemf.fileExtension, "3mf")
        XCTAssertTrue(threemf.displayName.contains("3MF"))
        XCTAssertTrue(threemf.is3DFormat)
    }

    func testDXFFormat() {
        let dxf = ExportFormat.dxf
        XCTAssertEqual(dxf.rawValue, "dxf")
        XCTAssertEqual(dxf.fileExtension, "dxf")
        XCTAssertTrue(dxf.displayName.contains("DXF"))
        XCTAssertFalse(dxf.is3DFormat)
    }

    func testSVGFormat() {
        let svg = ExportFormat.svg
        XCTAssertEqual(svg.rawValue, "svg")
        XCTAssertEqual(svg.fileExtension, "svg")
        XCTAssertTrue(svg.displayName.contains("SVG"))
        XCTAssertFalse(svg.is3DFormat)
    }

    func testPNGFormat() {
        let png = ExportFormat.png
        XCTAssertEqual(png.rawValue, "png")
        XCTAssertEqual(png.fileExtension, "png")
        XCTAssertTrue(png.displayName.contains("PNG"))
        XCTAssertFalse(png.is3DFormat)
    }

    func testAllowedContentTypes() {
        for format in ExportFormat.allCases {
            XCTAssertEqual(format.allowedContentTypes.count, 1)
            XCTAssertEqual(format.allowedContentTypes.first, format.fileExtension)
        }
    }

    func testCaseIterable() {
        // Verify we have all expected formats
        let expectedFormats: Set<ExportFormat> = [
            .stl, .obj, .off, .amf, .threemf, .dxf, .svg, .csg, .png
        ]
        let actualFormats = Set(ExportFormat.allCases)
        XCTAssertEqual(expectedFormats, actualFormats)
        XCTAssertEqual(ExportFormat.allCases.count, 9)
    }
}
