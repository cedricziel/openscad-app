import XCTest

@testable import OpenSCADApp

final class OpenSCADCompletionProviderTests: XCTestCase {

    var provider: OpenSCADCompletionProvider!

    override func setUpWithError() throws {
        provider = OpenSCADCompletionProvider()
    }

    override func tearDownWithError() throws {
        provider = nil
    }

    // MARK: - All Completions Tests

    func testAllCompletionsNotEmpty() {
        XCTAssertFalse(provider.allCompletions.isEmpty, "All completions should not be empty")
    }

    func testAllCompletionsContainsKeywords() {
        let keywords = ["module", "function", "if", "else", "for", "true", "false"]
        for keyword in keywords {
            let hasKeyword = provider.allCompletions.contains { $0.label == keyword }
            XCTAssertTrue(hasKeyword, "All completions should contain keyword '\(keyword)'")
        }
    }

    func testAllCompletionsContainsPrimitives() {
        let primitives = ["cube", "sphere", "cylinder", "circle", "square"]
        for primitive in primitives {
            let hasPrimitive = provider.allCompletions.contains { $0.label == primitive }
            XCTAssertTrue(hasPrimitive, "All completions should contain primitive '\(primitive)'")
        }
    }

    func testAllCompletionsContainsTransformations() {
        let transformations = ["translate", "rotate", "scale", "mirror", "hull"]
        for transform in transformations {
            let hasTransform = provider.allCompletions.contains { $0.label == transform }
            XCTAssertTrue(hasTransform, "All completions should contain transformation '\(transform)'")
        }
    }

    func testAllCompletionsContainsMathFunctions() {
        let mathFunctions = ["sin", "cos", "tan", "sqrt", "abs", "min", "max"]
        for func_ in mathFunctions {
            let hasFunc = provider.allCompletions.contains { $0.label == func_ }
            XCTAssertTrue(hasFunc, "All completions should contain math function '\(func_)'")
        }
    }

    func testAllCompletionsContainsSpecialVariables() {
        let specialVars = ["$fn", "$fa", "$fs", "$t", "$preview"]
        for varName in specialVars {
            let hasVar = provider.allCompletions.contains { $0.label == varName }
            XCTAssertTrue(hasVar, "All completions should contain special variable '\(varName)'")
        }
    }

    // MARK: - Prefix Matching Tests

    func testCompletionsForEmptyPrefix() {
        let completions = provider.completions(for: "")
        XCTAssertTrue(completions.isEmpty, "Empty prefix should return no completions")
    }

    func testCompletionsForSingleChar() {
        let completions = provider.completions(for: "c")
        XCTAssertFalse(completions.isEmpty, "Single char 'c' should return completions")

        let labels = completions.map { $0.label }
        XCTAssertTrue(labels.contains("cube"), "Completions for 'c' should contain 'cube'")
        XCTAssertTrue(labels.contains("circle"), "Completions for 'c' should contain 'circle'")
        XCTAssertTrue(labels.contains("cylinder"), "Completions for 'c' should contain 'cylinder'")
    }

    func testCompletionsForCube() {
        let completions = provider.completions(for: "cu")
        XCTAssertFalse(completions.isEmpty, "Prefix 'cu' should return completions")

        let labels = completions.map { $0.label }
        XCTAssertTrue(labels.contains("cube"), "Completions for 'cu' should contain 'cube'")
        XCTAssertFalse(labels.contains("circle"), "Completions for 'cu' should not contain 'circle'")
    }

    func testCompletionsForModule() {
        let completions = provider.completions(for: "mod")
        XCTAssertFalse(completions.isEmpty, "Prefix 'mod' should return completions")

        let labels = completions.map { $0.label }
        XCTAssertTrue(labels.contains("module"), "Completions for 'mod' should contain 'module'")
    }

    func testCompletionsAreCaseInsensitive() {
        let lowerCompletions = provider.completions(for: "cube")
        let upperCompletions = provider.completions(for: "CUBE")
        let mixedCompletions = provider.completions(for: "CuBe")

        XCTAssertEqual(lowerCompletions.count, upperCompletions.count)
        XCTAssertEqual(lowerCompletions.count, mixedCompletions.count)
    }

    func testCompletionsForSpecialVariable() {
        let completions = provider.completions(for: "$f")
        XCTAssertFalse(completions.isEmpty, "Prefix '$f' should return completions")

        let labels = completions.map { $0.label }
        XCTAssertTrue(labels.contains("$fn"), "Completions for '$f' should contain '$fn'")
        XCTAssertTrue(labels.contains("$fa"), "Completions for '$f' should contain '$fa'")
        XCTAssertTrue(labels.contains("$fs"), "Completions for '$f' should contain '$fs'")
    }

    func testNoCompletionsForNonMatchingPrefix() {
        let completions = provider.completions(for: "xyz")
        XCTAssertTrue(completions.isEmpty, "Non-matching prefix 'xyz' should return no completions")
    }

    // MARK: - Completion Sorting Tests

    func testCompletionsAreSortedByRelevance() {
        let completions = provider.completions(for: "tr")
        XCTAssertFalse(completions.isEmpty)

        // Shorter matches should come before longer ones
        if completions.count >= 2 {
            let firstLabel = completions[0].label
            // "true" is shorter and should come before "translate"
            XCTAssertEqual(firstLabel, "true", "Shorter match 'true' should come before 'translate'")
        }
    }

    // MARK: - Extract Prefix Tests

    func testExtractPrefixAtEnd() {
        let text = "cube"
        let prefix = provider.extractPrefix(from: text, at: 4)
        XCTAssertEqual(prefix, "cube")
    }

    func testExtractPrefixInMiddle() {
        let text = "cube(); sphere();"
        let prefix = provider.extractPrefix(from: text, at: 4)
        XCTAssertEqual(prefix, "cube")
    }

    func testExtractPrefixAfterSpace() {
        let text = "translate([0, 0, 0]) cu"
        let prefix = provider.extractPrefix(from: text, at: text.count)
        XCTAssertEqual(prefix, "cu")
    }

    func testExtractPrefixAfterOpenParen() {
        let text = "translate(cu"
        let prefix = provider.extractPrefix(from: text, at: text.count)
        XCTAssertEqual(prefix, "cu")
    }

    func testExtractPrefixForSpecialVariable() {
        let text = "$fn"
        let prefix = provider.extractPrefix(from: text, at: 3)
        XCTAssertEqual(prefix, "$fn")
    }

    func testExtractPrefixReturnsNilForEmptyPosition() {
        let text = "cube"
        let prefix = provider.extractPrefix(from: text, at: 0)
        XCTAssertNil(prefix)
    }

    func testExtractPrefixReturnsNilAfterSpace() {
        let text = "cube "
        let prefix = provider.extractPrefix(from: text, at: 5)
        XCTAssertNil(prefix)
    }

    func testExtractPrefixReturnsNilAfterOpenBracket() {
        let text = "cube["
        let prefix = provider.extractPrefix(from: text, at: 5)
        XCTAssertNil(prefix)
    }

    // MARK: - Completion Item Tests

    func testCompletionItemHasInsertText() {
        let cubeCompletions = provider.allCompletions.filter { $0.label == "cube" }
        XCTAssertEqual(cubeCompletions.count, 1)

        let cube = cubeCompletions[0]
        XCTAssertFalse(cube.insertText.isEmpty)
        XCTAssertTrue(cube.insertText.contains("cube"))
    }

    func testCompletionItemHasDocumentation() {
        let cubeCompletions = provider.allCompletions.filter { $0.label == "cube" }
        XCTAssertEqual(cubeCompletions.count, 1)

        let cube = cubeCompletions[0]
        XCTAssertNotNil(cube.documentation)
        XCTAssertFalse(cube.documentation!.isEmpty)
    }

    func testCompletionItemKinds() {
        let moduleCompletion = provider.allCompletions.first { $0.label == "module" }
        XCTAssertNotNil(moduleCompletion)
        XCTAssertEqual(moduleCompletion?.kind, .keyword)

        let cubeCompletion = provider.allCompletions.first { $0.label == "cube" }
        XCTAssertNotNil(cubeCompletion)
        XCTAssertEqual(cubeCompletion?.kind, .function)

        let fnCompletion = provider.allCompletions.first { $0.label == "$fn" }
        XCTAssertNotNil(fnCompletion)
        XCTAssertEqual(fnCompletion?.kind, .variable)
    }

    // MARK: - Completion Item Kind Icon Tests

    func testCompletionItemKindIcons() {
        XCTAssertEqual(CompletionItemKind.keyword.icon, "k")
        XCTAssertEqual(CompletionItemKind.function.icon, "ƒ")
        XCTAssertEqual(CompletionItemKind.module.icon, "m")
        XCTAssertEqual(CompletionItemKind.variable.icon, "$")
        XCTAssertEqual(CompletionItemKind.snippet.icon, "⌘")
    }

    // MARK: - Snippet Tests

    func testSnippetsExist() {
        let snippets = provider.allCompletions.filter { $0.kind == .snippet }
        XCTAssertFalse(snippets.isEmpty, "Snippets should exist")
    }

    func testModuleTemplateSnippetExists() {
        let moduleTemplate = provider.allCompletions.first { $0.label == "module_template" }
        XCTAssertNotNil(moduleTemplate, "Module template snippet should exist")
        XCTAssertEqual(moduleTemplate?.kind, .snippet)
    }

    // MARK: - Edge Cases

    func testExtractPrefixWithInvalidPosition() {
        let text = "cube"
        let prefix1 = provider.extractPrefix(from: text, at: -1)
        XCTAssertNil(prefix1)

        let prefix2 = provider.extractPrefix(from: text, at: 100)
        XCTAssertNil(prefix2)
    }

    func testExtractPrefixFromEmptyString() {
        let prefix = provider.extractPrefix(from: "", at: 0)
        XCTAssertNil(prefix)
    }

    func testCompletionsForVeryLongPrefix() {
        let longPrefix = "thisisaverylongprefixthatwontmatchanything"
        let completions = provider.completions(for: longPrefix)
        XCTAssertTrue(completions.isEmpty)
    }

    // MARK: - CSG Operations Tests

    func testCSGOperationsExist() {
        let csgOps = ["union", "difference", "intersection"]
        for op in csgOps {
            let completion = provider.allCompletions.first { $0.label == op }
            XCTAssertNotNil(completion, "CSG operation '\(op)' should exist")
            XCTAssertEqual(completion?.kind, .function)
        }
    }
}
