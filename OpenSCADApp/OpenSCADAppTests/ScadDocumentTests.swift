import XCTest
import UniformTypeIdentifiers
@testable import OpenSCADApp

final class ScadDocumentTests: XCTestCase {

    func testDefaultDocumentCreation() throws {
        let document = ScadDocument()

        XCTAssertFalse(document.text.isEmpty)
        XCTAssertTrue(document.text.contains("OpenSCAD"))
    }

    func testDocumentWithCustomText() throws {
        let customText = "sphere(r = 5);"
        let document = ScadDocument(text: customText)

        XCTAssertEqual(document.text, customText)
    }

    func testReadableContentTypes() {
        let types = ScadDocument.readableContentTypes

        XCTAssertFalse(types.isEmpty)
        XCTAssertTrue(types.contains(.plainText))
    }

    func testWritableContentTypes() {
        let types = ScadDocument.writableContentTypes

        XCTAssertFalse(types.isEmpty)
        XCTAssertTrue(types.contains(.plainText))
    }

    func testScadUTType() {
        let scadType = UTType.scadSource

        XCTAssertNotNil(scadType)
        XCTAssertTrue(scadType.conforms(to: .sourceCode))
    }

    func testDocumentTextMutation() throws {
        var document = ScadDocument(text: "cube([5, 5, 5]);")

        document.text = "sphere(r = 10);"

        XCTAssertEqual(document.text, "sphere(r = 10);")
    }

    func testDocumentTextEncoding() throws {
        let testText = "// Test with special chars: äöü ñ"
        let document = ScadDocument(text: testText)

        XCTAssertEqual(document.text, testText)
    }

    func testEmptyDocument() throws {
        let document = ScadDocument(text: "")

        XCTAssertTrue(document.text.isEmpty)
    }

    func testMultilineDocument() throws {
        let multilineText = """
        // First line
        cube([10, 10, 10]);
        // Second line
        sphere(r = 5);
        """

        let document = ScadDocument(text: multilineText)

        XCTAssertEqual(document.text, multilineText)
        XCTAssertTrue(document.text.contains("cube"))
        XCTAssertTrue(document.text.contains("sphere"))
    }
}
