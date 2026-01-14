import XCTest
@testable import OpenSCADApp

final class OpenSCADSyntaxHighlighterTests: XCTestCase {

    var highlighter: OpenSCADSyntaxHighlighter!

    override func setUpWithError() throws {
        highlighter = OpenSCADSyntaxHighlighter()
    }

    override func tearDownWithError() throws {
        highlighter = nil
    }

    // MARK: - Keyword Tests

    func testKeywordsAreRecognized() {
        let keywords = ["module", "function", "if", "else", "for", "let", "each",
                       "assert", "echo", "use", "include", "true", "false", "undef"]

        for keyword in keywords {
            XCTAssertTrue(OpenSCADSyntaxHighlighter.keywords.contains(keyword),
                          "Keyword '\(keyword)' should be recognized")
        }
    }

    func testHighlightingKeywords() {
        let code = "module test() { if (true) { echo(\"test\"); } }"
        let attributedString = highlighter.highlight(code)

        XCTAssertEqual(attributedString.string, code, "Highlighted text should match original")
    }

    // MARK: - Built-in Function Tests

    func testPrimitivesAreRecognized() {
        let primitives = ["cube", "sphere", "cylinder", "polyhedron",
                         "circle", "square", "polygon", "text"]

        for primitive in primitives {
            XCTAssertTrue(OpenSCADSyntaxHighlighter.primitives.contains(primitive),
                          "Primitive '\(primitive)' should be recognized")
        }
    }

    func testTransformationsAreRecognized() {
        let transformations = ["translate", "rotate", "scale", "mirror",
                              "linear_extrude", "rotate_extrude", "hull", "minkowski"]

        for transform in transformations {
            XCTAssertTrue(OpenSCADSyntaxHighlighter.transformations.contains(transform),
                          "Transformation '\(transform)' should be recognized")
        }
    }

    func testCSGOperationsAreRecognized() {
        let csgOps = ["union", "difference", "intersection"]

        for op in csgOps {
            XCTAssertTrue(OpenSCADSyntaxHighlighter.csgOperations.contains(op),
                          "CSG operation '\(op)' should be recognized")
        }
    }

    func testMathFunctionsAreRecognized() {
        let mathFuncs = ["sin", "cos", "tan", "sqrt", "pow", "abs", "floor", "ceil"]

        for func_ in mathFuncs {
            XCTAssertTrue(OpenSCADSyntaxHighlighter.mathFunctions.contains(func_),
                          "Math function '\(func_)' should be recognized")
        }
    }

    // MARK: - Highlighting Output Tests

    func testHighlightReturnsAttributedString() {
        let code = "cube([10, 10, 10]);"
        let result = highlighter.highlight(code)

        XCTAssertNotNil(result)
        XCTAssertEqual(result.string, code)
    }

    func testHighlightPreservesTextContent() {
        let complexCode = """
        // A complex example
        module rounded_box(size = [10, 10, 10], radius = 1) {
            $fn = 32;
            hull() {
                for (x = [radius, size.x - radius])
                    for (y = [radius, size.y - radius])
                        for (z = [radius, size.z - radius])
                            translate([x, y, z])
                                sphere(r = radius);
            }
        }

        difference() {
            rounded_box([30, 20, 10], 2);
            translate([5, 5, 2])
                cube([20, 10, 8]);
        }
        """

        let result = highlighter.highlight(complexCode)
        XCTAssertEqual(result.string, complexCode, "Highlighting should not alter text content")
    }

    func testEmptyStringHighlighting() {
        let result = highlighter.highlight("")
        XCTAssertEqual(result.string, "")
        XCTAssertEqual(result.length, 0)
    }

    // MARK: - Comment Tests

    func testSingleLineCommentHighlighting() {
        let code = "// This is a comment\ncube([10, 10, 10]);"
        let result = highlighter.highlight(code)

        XCTAssertEqual(result.string, code)
    }

    func testMultiLineCommentHighlighting() {
        let code = "/* Multi-line\ncomment */ cube([10, 10, 10]);"
        let result = highlighter.highlight(code)

        XCTAssertEqual(result.string, code)
    }

    // MARK: - String Tests

    func testStringHighlighting() {
        let code = "text(\"Hello World\");"
        let result = highlighter.highlight(code)

        XCTAssertEqual(result.string, code)
    }

    func testStringWithEscapedCharacters() {
        let code = "text(\"Line1\\nLine2\");"
        let result = highlighter.highlight(code)

        XCTAssertEqual(result.string, code)
    }

    // MARK: - Number Tests

    func testIntegerHighlighting() {
        let code = "cube([10, 20, 30]);"
        let result = highlighter.highlight(code)

        XCTAssertEqual(result.string, code)
    }

    func testFloatHighlighting() {
        let code = "sphere(r = 5.5);"
        let result = highlighter.highlight(code)

        XCTAssertEqual(result.string, code)
    }

    func testScientificNotationHighlighting() {
        let code = "x = 1.5e-3;"
        let result = highlighter.highlight(code)

        XCTAssertEqual(result.string, code)
    }

    // MARK: - Special Variable Tests

    func testSpecialVariableHighlighting() {
        let code = "$fn = 100; $fa = 1; $fs = 0.5;"
        let result = highlighter.highlight(code)

        XCTAssertEqual(result.string, code)
    }

    // MARK: - TextStorage Tests

    func testApplyHighlightingToTextStorage() {
        let textStorage = NSTextStorage(string: "cube([10, 10, 10]);")
        let initialLength = textStorage.length

        highlighter.applyHighlighting(to: textStorage)

        XCTAssertEqual(textStorage.length, initialLength, "Text length should not change")
        XCTAssertEqual(textStorage.string, "cube([10, 10, 10]);")
    }

    // MARK: - Color Configuration Tests

    func testDefaultColorsExist() {
        let colors = OpenSCADSyntaxHighlighter.SyntaxColors.default

        XCTAssertNotNil(colors.keyword)
        XCTAssertNotNil(colors.builtinFunction)
        XCTAssertNotNil(colors.number)
        XCTAssertNotNil(colors.string)
        XCTAssertNotNil(colors.comment)
        XCTAssertNotNil(colors.specialVariable)
        XCTAssertNotNil(colors.operator)
        XCTAssertNotNil(colors.defaultText)
    }

    func testCustomColors() {
        let customColors = OpenSCADSyntaxHighlighter.SyntaxColors(
            keyword: .red,
            builtinFunction: .blue,
            number: .green,
            string: .orange,
            comment: .gray,
            specialVariable: .cyan,
            operator: .magenta,
            defaultText: .black
        )

        let customHighlighter = OpenSCADSyntaxHighlighter(colors: customColors)
        XCTAssertNotNil(customHighlighter)
    }

    // MARK: - Edge Case Tests

    func testNestedStructures() {
        let code = """
        difference() {
            union() {
                cube([10, 10, 10]);
                translate([5, 5, 5])
                    sphere(r = 3);
            }
            cylinder(h = 15, r = 2, center = true);
        }
        """

        let result = highlighter.highlight(code)
        XCTAssertEqual(result.string, code)
    }

    func testMixedContent() {
        let code = """
        // Comment with keyword: module
        module test(size = 10, $fn = 32) {
            /* Another comment with function: cube */
            text("String with module keyword");
            cube([size, size, size]);
        }
        """

        let result = highlighter.highlight(code)
        XCTAssertEqual(result.string, code)
    }
}
