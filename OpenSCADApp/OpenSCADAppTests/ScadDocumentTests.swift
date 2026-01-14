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

    // MARK: - File Saving Tests

    func testDefaultFileExtension() {
        XCTAssertEqual(ScadDocument.defaultFileExtension, "scad")
    }

    func testDocumentDataConversion() throws {
        let testText = "cube([10, 10, 10]);"
        let document = ScadDocument(text: testText)

        // Test that the document text can be converted to UTF-8 data
        let data = document.text.data(using: .utf8)
        XCTAssertNotNil(data)

        // Test that the data can be read back correctly
        let savedText = String(data: data!, encoding: .utf8)
        XCTAssertEqual(savedText, testText)
    }

    func testDocumentWithUTF8Content() throws {
        let testText = """
        // OpenSCAD with UTF-8 characters
        // 日本語コメント
        // Émojis: 🔧 🎨 💾
        cube([10, 10, 10]);
        """
        let document = ScadDocument(text: testText)

        let data = document.text.data(using: .utf8)
        XCTAssertNotNil(data)

        let savedText = String(data: data!, encoding: .utf8)
        XCTAssertEqual(savedText, testText)
    }

    func testDocumentWithLargeContent() throws {
        // Create a large document with many lines
        var lines = [String]()
        for i in 0..<1000 {
            lines.append("// Line \(i)")
            lines.append("translate([\(i), 0, 0]) cube([1, 1, 1]);")
        }
        let largeText = lines.joined(separator: "\n")
        let document = ScadDocument(text: largeText)

        let data = document.text.data(using: .utf8)
        XCTAssertNotNil(data)

        let savedText = String(data: data!, encoding: .utf8)
        XCTAssertEqual(savedText, largeText)
    }

    func testDocumentSnapshot() {
        let testText = "sphere(r = 5);"
        let document = ScadDocument(text: testText)

        let snapshot = document.snapshot()

        XCTAssertEqual(snapshot, testText)
    }

    func testDocumentSnapshotReflectsChanges() {
        var document = ScadDocument(text: "cube([5, 5, 5]);")

        document.text = "sphere(r = 10);"
        let snapshot = document.snapshot()

        XCTAssertEqual(snapshot, "sphere(r = 10);")
    }

    func testRoundTripDataConversion() throws {
        let originalText = """
        // Test round trip
        module myShape() {
            union() {
                cube([10, 10, 10]);
                sphere(r = 7);
            }
        }
        myShape();
        """
        let document = ScadDocument(text: originalText)

        // Save to data
        let data = document.text.data(using: .utf8)!

        // Load back from data
        let loadedText = String(data: data, encoding: .utf8)

        XCTAssertEqual(loadedText, originalText)
    }

    func testWritableContentTypesIncludeScadSource() {
        let types = ScadDocument.writableContentTypes

        XCTAssertTrue(types.contains(UTType.scadSource))
    }

    func testReadableContentTypesIncludeScadSource() {
        let types = ScadDocument.readableContentTypes

        XCTAssertTrue(types.contains(UTType.scadSource))
    }

    func testEmptyDocumentDataConversion() throws {
        let document = ScadDocument(text: "")

        let data = document.text.data(using: .utf8)
        XCTAssertNotNil(data)

        let savedText = String(data: data!, encoding: .utf8)
        XCTAssertEqual(savedText, "")
    }

    func testSaveToTemporaryFile() throws {
        let testText = "sphere(r = 5);"
        let document = ScadDocument(text: testText)

        // Create a temporary file path
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test.\(ScadDocument.defaultFileExtension)")

        // Save the document
        let data = document.text.data(using: .utf8)!
        try data.write(to: tempFile, options: .atomic)

        // Read it back
        let loadedData = try Data(contentsOf: tempFile)
        let loadedText = String(data: loadedData, encoding: .utf8)

        XCTAssertEqual(loadedText, testText)

        // Clean up
        try FileManager.default.removeItem(at: tempFile)
    }

    func testSaveComplexDocument() throws {
        let testText = """
        // Complex OpenSCAD script
        $fn = 100;

        module roundedBox(size, radius) {
            hull() {
                for (x = [radius, size[0] - radius])
                    for (y = [radius, size[1] - radius])
                        translate([x, y, 0])
                            cylinder(r = radius, h = size[2]);
            }
        }

        difference() {
            roundedBox([30, 20, 10], 3);
            translate([5, 5, 2])
                cube([20, 10, 10]);
        }
        """
        let document = ScadDocument(text: testText)

        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("complex.\(ScadDocument.defaultFileExtension)")

        // Save
        let data = document.text.data(using: .utf8)!
        try data.write(to: tempFile, options: .atomic)

        // Load
        let loadedData = try Data(contentsOf: tempFile)
        let loadedText = String(data: loadedData, encoding: .utf8)

        XCTAssertEqual(loadedText, testText)

        // Clean up
        try FileManager.default.removeItem(at: tempFile)
    }
}
