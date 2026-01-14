import XCTest

@testable import OpenSCADApp

final class CodeCompletionProviderTests: XCTestCase {

  var provider: CodeCompletionProvider!

  override func setUpWithError() throws {
    provider = CodeCompletionProvider()
  }

  override func tearDownWithError() throws {
    provider = nil
  }

  // MARK: - Basic Completion Tests

  func testCompletionsReturnResults() {
    let completions = provider.completions(for: "cu")
    XCTAssertFalse(completions.isEmpty, "Should return completions for 'cu'")
    XCTAssertTrue(
      completions.contains { $0.text == "cube" }, "Should include 'cube' in completions for 'cu'")
  }

  func testCompletionsAreCaseInsensitive() {
    let completions = provider.completions(for: "CU")
    XCTAssertTrue(
      completions.contains { $0.text == "cube" }, "Should match 'cube' with uppercase prefix 'CU'")
  }

  func testEmptyPrefixReturnsAllCompletions() {
    let completions = provider.completions(for: "", limit: 100)
    XCTAssertGreaterThan(completions.count, 50, "Should return many completions for empty prefix")
  }

  func testCompletionLimit() {
    let limit = 5
    let completions = provider.completions(for: "", limit: limit)
    XCTAssertLessThanOrEqual(completions.count, limit, "Should respect the limit parameter")
  }

  func testNoCompletionsForNonMatching() {
    let completions = provider.completions(for: "xyznonexistent")
    XCTAssertTrue(completions.isEmpty, "Should return no completions for non-matching prefix")
  }

  // MARK: - Keyword Completions

  func testKeywordCompletions() {
    let moduleCompletions = provider.completions(for: "mod")
    XCTAssertTrue(
      moduleCompletions.contains { $0.text == "module" && $0.category == .keyword },
      "Should complete 'module' as a keyword")

    let functionCompletions = provider.completions(for: "func")
    XCTAssertTrue(
      functionCompletions.contains { $0.text == "function" && $0.category == .keyword },
      "Should complete 'function' as a keyword")
  }

  func testAllKeywordsAreCompletable() {
    let keywords = ["module", "function", "if", "else", "for", "let", "each", "include", "use"]

    for keyword in keywords {
      let prefix = String(keyword.prefix(2))
      let completions = provider.completions(for: prefix, limit: 50)
      XCTAssertTrue(
        completions.contains { $0.text == keyword },
        "Should find keyword '\(keyword)' when typing '\(prefix)'")
    }
  }

  // MARK: - Primitive Completions

  func testPrimitiveCompletions() {
    let cubeCompletions = provider.completions(for: "cub")
    XCTAssertTrue(
      cubeCompletions.contains { $0.text == "cube" && $0.category == .primitive },
      "Should complete 'cube' as a primitive")

    let sphereCompletions = provider.completions(for: "sph")
    XCTAssertTrue(
      sphereCompletions.contains { $0.text == "sphere" && $0.category == .primitive },
      "Should complete 'sphere' as a primitive")

    let cylinderCompletions = provider.completions(for: "cyl")
    XCTAssertTrue(
      cylinderCompletions.contains { $0.text == "cylinder" && $0.category == .primitive },
      "Should complete 'cylinder' as a primitive")
  }

  // MARK: - Transformation Completions

  func testTransformationCompletions() {
    let translateCompletions = provider.completions(for: "trans")
    XCTAssertTrue(
      translateCompletions.contains { $0.text == "translate" && $0.category == .transformation },
      "Should complete 'translate' as a transformation")

    let rotateCompletions = provider.completions(for: "rot")
    XCTAssertTrue(
      rotateCompletions.contains { $0.text == "rotate" && $0.category == .transformation },
      "Should complete 'rotate' as a transformation")
  }

  // MARK: - CSG Operation Completions

  func testCSGOperationCompletions() {
    let unionCompletions = provider.completions(for: "uni")
    XCTAssertTrue(
      unionCompletions.contains { $0.text == "union" && $0.category == .csgOperation },
      "Should complete 'union' as a CSG operation")

    let differenceCompletions = provider.completions(for: "diff")
    XCTAssertTrue(
      differenceCompletions.contains { $0.text == "difference" && $0.category == .csgOperation },
      "Should complete 'difference' as a CSG operation")
  }

  // MARK: - Math Function Completions

  func testMathFunctionCompletions() {
    let sinCompletions = provider.completions(for: "si")
    XCTAssertTrue(
      sinCompletions.contains { $0.text == "sin" && $0.category == .mathFunction },
      "Should complete 'sin' as a math function")

    let sqrtCompletions = provider.completions(for: "sqr")
    XCTAssertTrue(
      sqrtCompletions.contains { $0.text == "sqrt" && $0.category == .mathFunction },
      "Should complete 'sqrt' as a math function")
  }

  // MARK: - Special Variable Completions

  func testSpecialVariableCompletions() {
    let fnCompletions = provider.completions(for: "$f")
    XCTAssertTrue(
      fnCompletions.contains { $0.text == "$fn" && $0.category == .specialVariable },
      "Should complete '$fn' as a special variable")
    XCTAssertTrue(
      fnCompletions.contains { $0.text == "$fa" && $0.category == .specialVariable },
      "Should complete '$fa' as a special variable")
    XCTAssertTrue(
      fnCompletions.contains { $0.text == "$fs" && $0.category == .specialVariable },
      "Should complete '$fs' as a special variable")
  }

  func testDollarSignCompletions() {
    let completions = provider.completions(for: "$")
    XCTAssertFalse(completions.isEmpty, "Should return completions for '$'")
    XCTAssertTrue(
      completions.allSatisfy { $0.text.hasPrefix("$") },
      "All completions for '$' should start with '$'")
  }

  // MARK: - Completion Item Properties

  func testCompletionItemHasInsertText() {
    let completions = provider.completions(for: "cube")
    guard let cubeCompletion = completions.first(where: { $0.text == "cube" }) else {
      XCTFail("Should find cube completion")
      return
    }

    XCTAssertFalse(
      cubeCompletion.insertText.isEmpty, "Completion item should have insert text")
    XCTAssertTrue(
      cubeCompletion.insertText.contains("cube"), "Insert text should contain the function name")
  }

  func testCompletionItemHasDetail() {
    let completions = provider.completions(for: "cube")
    guard let cubeCompletion = completions.first(where: { $0.text == "cube" }) else {
      XCTFail("Should find cube completion")
      return
    }

    XCTAssertNotNil(cubeCompletion.detail, "Completion item should have detail description")
  }

  // MARK: - Partial Word Extraction Tests

  func testExtractPartialWordAtEnd() {
    let text = "cube"
    let result = provider.extractPartialWord(from: text, at: 4)

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.word, "cube")
    XCTAssertEqual(result?.startIndex, 0)
  }

  func testExtractPartialWordInMiddle() {
    let text = "translate cube sphere"
    let result = provider.extractPartialWord(from: text, at: 14)  // After "cube"

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.word, "cube")
    XCTAssertEqual(result?.startIndex, 10)
  }

  func testExtractPartialWordWithPrefix() {
    let text = "function test() { cu"
    let result = provider.extractPartialWord(from: text, at: 20)

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.word, "cu")
    XCTAssertEqual(result?.startIndex, 18)
  }

  func testExtractPartialWordWithSpecialVariable() {
    let text = "$fn = 100; $f"
    let result = provider.extractPartialWord(from: text, at: 13)

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.word, "$f")
  }

  func testExtractPartialWordAtStartOfLine() {
    let text = "cube"
    let result = provider.extractPartialWord(from: text, at: 4)

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.word, "cube")
    XCTAssertEqual(result?.startIndex, 0)
  }

  func testExtractPartialWordReturnsNilForNoWord() {
    let text = "cube "
    let result = provider.extractPartialWord(from: text, at: 5)  // After space

    XCTAssertNil(result, "Should return nil when cursor is not in a word")
  }

  func testExtractPartialWordReturnsNilAtStart() {
    let text = "cube"
    let result = provider.extractPartialWord(from: text, at: 0)

    XCTAssertNil(result, "Should return nil at position 0")
  }

  // MARK: - Should Trigger Completion Tests

  func testShouldTriggerCompletionForPartialWord() {
    let text = "cu"
    XCTAssertTrue(
      provider.shouldTriggerCompletion(in: text, at: 2),
      "Should trigger completion for partial word")
  }

  func testShouldTriggerCompletionForDollarSign() {
    let text = "$"
    XCTAssertTrue(
      provider.shouldTriggerCompletion(in: text, at: 1),
      "Should trigger completion for '$'")
  }

  func testShouldNotTriggerAfterSpace() {
    let text = "cube "
    XCTAssertFalse(
      provider.shouldTriggerCompletion(in: text, at: 5),
      "Should not trigger completion after space")
  }

  // MARK: - Completion Sorting Tests

  func testCompletionsSortedByRelevance() {
    let completions = provider.completions(for: "cu")

    // "cube" should appear before "include" since it starts with "cu"
    if let cubeIndex = completions.firstIndex(where: { $0.text == "cube" }),
      let includeIndex = completions.firstIndex(where: { $0.text == "include" })
    {
      XCTAssertLessThan(cubeIndex, includeIndex, "Prefix matches should rank higher than contains")
    }
  }

  func testShorterMatchesRankHigher() {
    let completions = provider.completions(for: "s")

    // Among prefix matches, shorter ones should rank higher
    // "str" should appear before "string" related functions
    let strIndex = completions.firstIndex { $0.text == "str" }
    let searchIndex = completions.firstIndex { $0.text == "search" }

    if let strIdx = strIndex, let searchIdx = searchIndex {
      XCTAssertLessThan(strIdx, searchIdx, "Shorter matches should rank higher")
    }
  }

  // MARK: - Category Tests

  func testAllCategoriesHaveIcons() {
    for category in CodeCompletionProvider.CompletionItem.Category.allCases {
      XCTAssertFalse(category.icon.isEmpty, "Category \(category) should have an icon")
    }
  }

  // MARK: - Edge Cases

  func testCompletionWithUnderscores() {
    let completions = provider.completions(for: "linear")
    XCTAssertTrue(
      completions.contains { $0.text == "linear_extrude" },
      "Should complete functions with underscores")
  }

  func testCompletionPreservesCase() {
    let completions = provider.completions(for: "CUBE")
    guard let cubeCompletion = completions.first(where: { $0.text == "cube" }) else {
      XCTFail("Should find cube completion")
      return
    }

    XCTAssertEqual(cubeCompletion.text, "cube", "Completion text should be in original case")
  }
}
