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
}
