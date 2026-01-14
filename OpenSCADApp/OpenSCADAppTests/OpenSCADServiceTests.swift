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

        let exportError = OpenSCADError.exportFailed("export error")
        XCTAssertNotNil(exportError.errorDescription)
        XCTAssertTrue(exportError.errorDescription!.contains("export error"))

        let unsupportedError = OpenSCADError.unsupportedFormat("xyz")
        XCTAssertNotNil(unsupportedError.errorDescription)
        XCTAssertTrue(unsupportedError.errorDescription!.contains("xyz"))
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

    // MARK: - Export Format Tests

    func testExportFormatDisplayNames() {
        XCTAssertEqual(ExportFormat.stl.displayName, "STL (Stereolithography)")
        XCTAssertEqual(ExportFormat.obj.displayName, "OBJ (Wavefront)")
        XCTAssertEqual(ExportFormat.off.displayName, "OFF (Object File Format)")
        XCTAssertEqual(ExportFormat.amf.displayName, "AMF (Additive Manufacturing)")
        XCTAssertEqual(ExportFormat.threemf.displayName, "3MF (3D Manufacturing)")
        XCTAssertEqual(ExportFormat.dxf.displayName, "DXF (AutoCAD)")
        XCTAssertEqual(ExportFormat.svg.displayName, "SVG (Scalable Vector Graphics)")
        XCTAssertEqual(ExportFormat.csg.displayName, "CSG (Constructive Solid Geometry)")
        XCTAssertEqual(ExportFormat.png.displayName, "PNG (Image)")
    }

    func testExportFormatFileExtensions() {
        XCTAssertEqual(ExportFormat.stl.fileExtension, "stl")
        XCTAssertEqual(ExportFormat.obj.fileExtension, "obj")
        XCTAssertEqual(ExportFormat.off.fileExtension, "off")
        XCTAssertEqual(ExportFormat.amf.fileExtension, "amf")
        XCTAssertEqual(ExportFormat.threemf.fileExtension, "3mf")
        XCTAssertEqual(ExportFormat.dxf.fileExtension, "dxf")
        XCTAssertEqual(ExportFormat.svg.fileExtension, "svg")
        XCTAssertEqual(ExportFormat.csg.fileExtension, "csg")
        XCTAssertEqual(ExportFormat.png.fileExtension, "png")
    }

    func testExportFormat3DPrintable() {
        // 3D printable formats
        XCTAssertTrue(ExportFormat.stl.is3DPrintable)
        XCTAssertTrue(ExportFormat.obj.is3DPrintable)
        XCTAssertTrue(ExportFormat.off.is3DPrintable)
        XCTAssertTrue(ExportFormat.amf.is3DPrintable)
        XCTAssertTrue(ExportFormat.threemf.is3DPrintable)

        // Non-3D printable formats
        XCTAssertFalse(ExportFormat.dxf.is3DPrintable)
        XCTAssertFalse(ExportFormat.svg.is3DPrintable)
        XCTAssertFalse(ExportFormat.csg.is3DPrintable)
        XCTAssertFalse(ExportFormat.png.is3DPrintable)
    }

    func testExportFormatPrintableFormats() {
        let printableFormats = ExportFormat.printableFormats

        XCTAssertEqual(printableFormats.count, 5)
        XCTAssertTrue(printableFormats.contains(.stl))
        XCTAssertTrue(printableFormats.contains(.obj))
        XCTAssertTrue(printableFormats.contains(.off))
        XCTAssertTrue(printableFormats.contains(.amf))
        XCTAssertTrue(printableFormats.contains(.threemf))
    }

    func testExportFormatIdentifiable() {
        // Test that each format has a unique ID
        let allIDs = ExportFormat.allCases.map { $0.id }
        let uniqueIDs = Set(allIDs)
        XCTAssertEqual(allIDs.count, uniqueIDs.count, "Each format should have a unique ID")
    }

    @MainActor
    func testExportWithoutOpenSCAD() async {
        let service = OpenSCADService()

        // If OpenSCAD is not available, export should throw
        if !service.isOpenSCADAvailable {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.stl")

            do {
                try await service.export(script: "cube([10, 10, 10]);", format: .stl, to: tempURL)
                XCTFail("Expected error when OpenSCAD is not installed")
            } catch let error as OpenSCADError {
                XCTAssertEqual(error.errorDescription, OpenSCADError.notInstalled.errorDescription)
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    @MainActor
    func testExportToDataWithoutOpenSCAD() async {
        let service = OpenSCADService()

        // If OpenSCAD is not available, exportToData should throw
        if !service.isOpenSCADAvailable {
            do {
                _ = try await service.exportToData(script: "cube([10, 10, 10]);", format: .stl)
                XCTFail("Expected error when OpenSCAD is not installed")
            } catch let error as OpenSCADError {
                XCTAssertEqual(error.errorDescription, OpenSCADError.notInstalled.errorDescription)
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
}
