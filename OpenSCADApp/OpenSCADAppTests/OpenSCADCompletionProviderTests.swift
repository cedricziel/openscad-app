import XCTest

@testable import OpenSCADApp

final class OpenSCADCompletionProviderTests: XCTestCase {

  var provider: OpenSCADCompletionProvider!

  override func setUp() {
    super.setUp()
    provider = OpenSCADCompletionProvider()
  }

  override func tearDown() {
    provider = nil
    super.tearDown()
  }

  // MARK: - Basic Completion Tests

  func testCompletionsForCubePrefix() {
    let completions = provider.completions(for: "cu", in: "")

    XCTAssertFalse(completions.isEmpty, "Should return completions for 'cu'")

    let cubeCompletion = completions.first { $0.text == "cube" }
    XCTAssertNotNil(cubeCompletion, "Should include 'cube' in completions")
    XCTAssertEqual(cubeCompletion?.category, .primitive)
  }

  func testCompletionsForSpherePrefix() {
    let completions = provider.completions(for: "sp", in: "")

    let sphereCompletion = completions.first { $0.text == "sphere" }
    XCTAssertNotNil(sphereCompletion, "Should include 'sphere' in completions")
    XCTAssertEqual(sphereCompletion?.category, .primitive)
  }

  func testCompletionsForModuleKeyword() {
    let completions = provider.completions(for: "mod", in: "")

    let moduleCompletion = completions.first { $0.text == "module" }
    XCTAssertNotNil(moduleCompletion, "Should include 'module' in completions")
    XCTAssertEqual(moduleCompletion?.category, .keyword)
  }

  func testCompletionsForTranslate() {
    let completions = provider.completions(for: "trans", in: "")

    let translateCompletion = completions.first { $0.text == "translate" }
    XCTAssertNotNil(translateCompletion, "Should include 'translate' in completions")
    XCTAssertEqual(translateCompletion?.category, .transformation)
  }

  func testCompletionsForDifference() {
    let completions = provider.completions(for: "diff", in: "")

    let differenceCompletion = completions.first { $0.text == "difference" }
    XCTAssertNotNil(differenceCompletion, "Should include 'difference' in completions")
    XCTAssertEqual(differenceCompletion?.category, .csgOperation)
  }

  func testCompletionsForMathFunction() {
    let completions = provider.completions(for: "sq", in: "")

    let sqrtCompletion = completions.first { $0.text == "sqrt" }
    XCTAssertNotNil(sqrtCompletion, "Should include 'sqrt' in completions")
    XCTAssertEqual(sqrtCompletion?.category, .mathFunction)
  }

  func testCompletionsForSpecialVariable() {
    let completions = provider.completions(for: "$f", in: "")

    let fnCompletion = completions.first { $0.text == "$fn" }
    XCTAssertNotNil(fnCompletion, "Should include '$fn' in completions")
    XCTAssertEqual(fnCompletion?.category, .specialVariable)
  }

  // MARK: - Empty Prefix Tests

  func testNoCompletionsForEmptyPrefix() {
    let completions = provider.completions(for: "", in: "")
    XCTAssertTrue(completions.isEmpty, "Should return no completions for empty prefix")
  }

  func testNoCompletionsForNonMatchingPrefix() {
    let completions = provider.completions(for: "xyz", in: "")
    XCTAssertTrue(completions.isEmpty, "Should return no completions for non-matching prefix")
  }

  // MARK: - Case Insensitivity Tests

  func testCaseInsensitiveMatching() {
    let completionsLower = provider.completions(for: "cu", in: "")
    let completionsUpper = provider.completions(for: "CU", in: "")

    XCTAssertEqual(
      completionsLower.count, completionsUpper.count,
      "Should return same completions regardless of case")
  }

  // MARK: - User-Defined Symbol Tests

  func testExtractsUserDefinedModules() {
    let code = """
      module myCustomModule(size) {
          cube(size);
      }

      myC
      """

    let completions = provider.completions(for: "myC", in: code)

    let customModuleCompletion = completions.first { $0.text == "myCustomModule" }
    XCTAssertNotNil(customModuleCompletion, "Should include user-defined module in completions")
    XCTAssertEqual(customModuleCompletion?.category, .userDefined)
  }

  func testExtractsUserDefinedFunctions() {
    let code = """
      function calculateArea(r) = PI * r * r;

      calc
      """

    let completions = provider.completions(for: "calc", in: code)

    let customFunctionCompletion = completions.first { $0.text == "calculateArea" }
    XCTAssertNotNil(customFunctionCompletion, "Should include user-defined function in completions")
    XCTAssertEqual(customFunctionCompletion?.category, .userDefined)
  }

  func testExtractsUserDefinedVariables() {
    let code = """
      myVariable = 42;

      myV
      """

    let completions = provider.completions(for: "myV", in: code)

    let variableCompletion = completions.first { $0.text == "myVariable" }
    XCTAssertNotNil(variableCompletion, "Should include user-defined variable in completions")
    XCTAssertEqual(variableCompletion?.category, .userDefined)
  }

  // MARK: - Word Prefix Extraction Tests

  func testCurrentWordPrefixAtEndOfWord() {
    let text = "cub"
    let cursorPosition = 3

    let result = provider.currentWordPrefix(in: text, at: cursorPosition)

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.prefix, "cub")
    XCTAssertEqual(result?.range.location, 0)
    XCTAssertEqual(result?.range.length, 3)
  }

  func testCurrentWordPrefixInMiddleOfLine() {
    let text = "translate(cub"
    let cursorPosition = 13

    let result = provider.currentWordPrefix(in: text, at: cursorPosition)

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.prefix, "cub")
    XCTAssertEqual(result?.range.location, 10)
    XCTAssertEqual(result?.range.length, 3)
  }

  func testCurrentWordPrefixAfterOperator() {
    let text = "x = sph"
    let cursorPosition = 7

    let result = provider.currentWordPrefix(in: text, at: cursorPosition)

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.prefix, "sph")
  }

  func testCurrentWordPrefixForSpecialVariable() {
    let text = "$f"
    let cursorPosition = 2

    let result = provider.currentWordPrefix(in: text, at: cursorPosition)

    XCTAssertNotNil(result, "Should recognize $ prefix for special variables")
    XCTAssertEqual(result?.prefix, "$f")
  }

  func testNoWordPrefixForSingleCharacter() {
    let text = "c"
    let cursorPosition = 1

    let result = provider.currentWordPrefix(in: text, at: cursorPosition)

    XCTAssertNil(
      result, "Should not return prefix for single character (except for $ variables)")
  }

  func testNoWordPrefixAtStartOfFile() {
    let text = "cube()"
    let cursorPosition = 0

    let result = provider.currentWordPrefix(in: text, at: cursorPosition)

    XCTAssertNil(result, "Should not return prefix when cursor is at position 0")
  }

  // MARK: - Sorting and Priority Tests

  func testCompletionsSortedByRelevance() {
    let completions = provider.completions(for: "cu", in: "", maxResults: 100)

    // Should return completions for "cu" prefix
    XCTAssertFalse(completions.isEmpty, "Should return completions for 'cu' prefix")

    // Cube should be among the results
    let hasCube = completions.contains { $0.text == "cube" }
    XCTAssertTrue(hasCube, "Should include 'cube' in results for 'cu' prefix")
  }

  func testMaxResultsLimit() {
    let completions = provider.completions(for: "c", in: "", maxResults: 5)

    XCTAssertLessThanOrEqual(
      completions.count, 5, "Should respect maxResults limit")
  }

  // MARK: - Insertion Text Tests

  func testCubeInsertionText() {
    let completions = provider.completions(for: "cub", in: "")

    let cubeCompletion = completions.first { $0.text == "cube" }
    XCTAssertNotNil(cubeCompletion)
    XCTAssertTrue(
      cubeCompletion?.insertionText.contains("[") == true,
      "Cube insertion text should include array syntax")
  }

  func testModuleInsertionText() {
    let completions = provider.completions(for: "mod", in: "")

    let moduleCompletion = completions.first { $0.text == "module" }
    XCTAssertNotNil(moduleCompletion)
    XCTAssertTrue(
      moduleCompletion?.insertionText.contains("{") == true,
      "Module insertion text should include braces")
  }

  func testUseInsertionText() {
    let completions = provider.completions(for: "us", in: "")

    let useCompletion = completions.first { $0.text == "use" }
    XCTAssertNotNil(useCompletion)
    XCTAssertTrue(
      useCompletion?.insertionText.contains("<") == true,
      "Use insertion text should include angle brackets")
  }

  // MARK: - Documentation Tests

  func testCompletionHasDocumentation() {
    let completions = provider.completions(for: "cub", in: "")

    let cubeCompletion = completions.first { $0.text == "cube" }
    XCTAssertNotNil(cubeCompletion?.documentation, "Completions should have documentation")
    XCTAssertFalse(
      cubeCompletion?.documentation?.isEmpty == true,
      "Documentation should not be empty")
  }

  // MARK: - Category Icon Tests

  func testCategoryIcons() {
    XCTAssertEqual(CompletionCategory.keyword.icon, "k")
    XCTAssertEqual(CompletionCategory.primitive.icon, "P")
    XCTAssertEqual(CompletionCategory.transformation.icon, "T")
    XCTAssertEqual(CompletionCategory.csgOperation.icon, "C")
    XCTAssertEqual(CompletionCategory.mathFunction.icon, "f")
    XCTAssertEqual(CompletionCategory.specialVariable.icon, "$")
  }

  // MARK: - Duplicate Removal Tests

  func testNoDuplicateCompletions() {
    let code = """
      module cube() { }  // User-defined cube that shadows built-in

      cub
      """

    let completions = provider.completions(for: "cub", in: code)

    let cubeCompletions = completions.filter { $0.text == "cube" }
    XCTAssertEqual(
      cubeCompletions.count, 1, "Should not have duplicate completions for same name")
  }

  // MARK: - All Built-in Categories Tests

  func testAllKeywordsAvailable() {
    let keywords = ["module", "function", "if", "else", "for", "let", "use", "include"]

    for keyword in keywords {
      let prefix = String(keyword.prefix(2))
      let completions = provider.completions(for: prefix, in: "")
      let hasKeyword = completions.contains { $0.text == keyword }
      XCTAssertTrue(hasKeyword, "Should include keyword '\(keyword)' in completions")
    }
  }

  func testAllPrimitivesAvailable() {
    let primitives = ["cube", "sphere", "cylinder", "circle", "square", "polygon", "text"]

    for primitive in primitives {
      let prefix = String(primitive.prefix(2))
      let completions = provider.completions(for: prefix, in: "")
      let hasPrimitive = completions.contains { $0.text == primitive }
      XCTAssertTrue(hasPrimitive, "Should include primitive '\(primitive)' in completions")
    }
  }

  func testAllCSGOperationsAvailable() {
    let csgOps = ["union", "difference", "intersection"]

    for op in csgOps {
      let prefix = String(op.prefix(2))
      let completions = provider.completions(for: prefix, in: "")
      let hasOp = completions.contains { $0.text == op }
      XCTAssertTrue(hasOp, "Should include CSG operation '\(op)' in completions")
    }
  }

  func testAllSpecialVariablesAvailable() {
    let specialVars = ["$fn", "$fa", "$fs", "$t", "$preview"]

    for variable in specialVars {
      let prefix = String(variable.prefix(2))
      let completions = provider.completions(for: prefix, in: "")
      let hasVar = completions.contains { $0.text == variable }
      XCTAssertTrue(hasVar, "Should include special variable '\(variable)' in completions")
    }
  }
}
