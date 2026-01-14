import AppKit
import Foundation

/// A syntax highlighter for OpenSCAD code that provides colored highlighting
/// for keywords, functions, numbers, strings, comments, and special variables.
final class OpenSCADSyntaxHighlighter {

  // MARK: - Syntax Colors

  /// Colors used for syntax highlighting, adapting to system appearance
  struct SyntaxColors {
    let keyword: NSColor
    let builtinFunction: NSColor
    let number: NSColor
    let string: NSColor
    let comment: NSColor
    let specialVariable: NSColor
    let `operator`: NSColor
    let defaultText: NSColor

    static var `default`: SyntaxColors {
      SyntaxColors(
        keyword: NSColor.systemPurple,
        builtinFunction: NSColor.systemBlue,
        number: NSColor.systemOrange,
        string: NSColor.systemRed,
        comment: NSColor.systemGreen,
        specialVariable: NSColor.systemTeal,
        operator: NSColor.systemPink,
        defaultText: NSColor.textColor
      )
    }
  }

  // MARK: - Token Types

  enum TokenType {
    case keyword
    case builtinFunction
    case number
    case string
    case comment
    case specialVariable
    case `operator`
    case defaultText
  }

  // MARK: - OpenSCAD Language Keywords

  /// Language keywords that control program flow and structure
  static let keywords: Set<String> = [
    "module", "function", "if", "else", "for", "let", "each",
    "assert", "echo", "use", "include", "true", "false", "undef",
  ]

  /// Built-in 3D and 2D primitives
  static let primitives: Set<String> = [
    // 3D primitives
    "cube", "sphere", "cylinder", "polyhedron",
    // 2D primitives
    "circle", "square", "polygon", "text",
  ]

  /// Built-in transformation functions
  static let transformations: Set<String> = [
    "translate", "rotate", "scale", "mirror", "multmatrix",
    "color", "offset", "hull", "minkowski",
    "linear_extrude", "rotate_extrude", "surface", "projection",
    "resize", "render", "children",
  ]

  /// CSG (Constructive Solid Geometry) operations
  static let csgOperations: Set<String> = [
    "union", "difference", "intersection",
  ]

  /// Built-in math functions
  static let mathFunctions: Set<String> = [
    "abs", "sign", "sin", "cos", "tan", "acos", "asin", "atan", "atan2",
    "floor", "round", "ceil", "ln", "log", "pow", "sqrt", "exp",
    "rands", "min", "max", "norm", "cross",
  ]

  /// Built-in list and string functions
  static let listStringFunctions: Set<String> = [
    "concat", "lookup", "str", "chr", "ord", "search",
    "version", "version_num", "len", "parent_module",
    "is_undef", "is_bool", "is_num", "is_string", "is_list", "is_function",
  ]

  /// All built-in functions combined
  static var builtinFunctions: Set<String> {
    primitives
      .union(transformations)
      .union(csgOperations)
      .union(mathFunctions)
      .union(listStringFunctions)
  }

  /// Special OpenSCAD variables that start with $
  static let specialVariablePatterns: [String] = [
    "$fn", "$fa", "$fs", "$t", "$vpr", "$vpt", "$vpd", "$vpf",
    "$children", "$preview",
  ]

  // MARK: - Properties

  let colors: SyntaxColors
  let font: NSFont

  // MARK: - Initialization

  init(
    colors: SyntaxColors = .default,
    font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
  ) {
    self.colors = colors
    self.font = font
  }

  // MARK: - Public Methods

  /// Applies syntax highlighting to the given text and returns an attributed string
  func highlight(_ text: String) -> NSAttributedString {
    let attributedString = NSMutableAttributedString(string: text)
    let fullRange = NSRange(location: 0, length: attributedString.length)

    // Set default attributes
    attributedString.addAttribute(.font, value: font, range: fullRange)
    attributedString.addAttribute(.foregroundColor, value: colors.defaultText, range: fullRange)

    // Apply highlighting in order of precedence (comments and strings take priority)
    highlightComments(in: attributedString, text: text)
    highlightStrings(in: attributedString, text: text)
    highlightSpecialVariables(in: attributedString, text: text)
    highlightKeywords(in: attributedString, text: text)
    highlightBuiltinFunctions(in: attributedString, text: text)
    highlightNumbers(in: attributedString, text: text)
    highlightOperators(in: attributedString, text: text)

    return attributedString
  }

  /// Applies syntax highlighting to an NSTextStorage in place
  func applyHighlighting(to textStorage: NSTextStorage) {
    let text = textStorage.string
    let fullRange = NSRange(location: 0, length: textStorage.length)

    textStorage.beginEditing()

    // Set default attributes
    textStorage.addAttribute(.font, value: font, range: fullRange)
    textStorage.addAttribute(.foregroundColor, value: colors.defaultText, range: fullRange)

    // Apply highlighting
    highlightComments(in: textStorage, text: text)
    highlightStrings(in: textStorage, text: text)
    highlightSpecialVariables(in: textStorage, text: text)
    highlightKeywords(in: textStorage, text: text)
    highlightBuiltinFunctions(in: textStorage, text: text)
    highlightNumbers(in: textStorage, text: text)
    highlightOperators(in: textStorage, text: text)

    textStorage.endEditing()
  }

  // MARK: - Private Highlighting Methods

  private func highlightComments(in attributedString: NSMutableAttributedString, text: String) {
    // Multi-line comments: /* ... */
    let multiLinePattern = #"/\*[\s\S]*?\*/"#
    applyPattern(
      multiLinePattern, to: attributedString, text: text, color: colors.comment, priority: .high)

    // Single-line comments: // ...
    let singleLinePattern = #"//[^\n]*"#
    applyPattern(
      singleLinePattern, to: attributedString, text: text, color: colors.comment, priority: .high)
  }

  private func highlightStrings(in attributedString: NSMutableAttributedString, text: String) {
    // Double-quoted strings with escape character support
    let stringPattern = #""(?:[^"\\]|\\.)*""#
    applyPattern(
      stringPattern, to: attributedString, text: text, color: colors.string, priority: .high,
      skipIfAlreadyHighlighted: true)
  }

  private func highlightSpecialVariables(
    in attributedString: NSMutableAttributedString, text: String
  ) {
    // Special variables starting with $
    let specialVarPattern = #"\$[a-zA-Z_][a-zA-Z0-9_]*"#
    applyPattern(
      specialVarPattern, to: attributedString, text: text, color: colors.specialVariable,
      skipIfAlreadyHighlighted: true)
  }

  private func highlightKeywords(in attributedString: NSMutableAttributedString, text: String) {
    for keyword in Self.keywords {
      let pattern = "\\b\(keyword)\\b"
      applyPattern(
        pattern, to: attributedString, text: text, color: colors.keyword,
        skipIfAlreadyHighlighted: true)
    }
  }

  private func highlightBuiltinFunctions(
    in attributedString: NSMutableAttributedString, text: String
  ) {
    for function in Self.builtinFunctions {
      // Match function names followed by an opening parenthesis (with optional whitespace)
      let pattern = "\\b\(function)\\s*(?=\\()"
      applyPattern(
        pattern, to: attributedString, text: text, color: colors.builtinFunction,
        skipIfAlreadyHighlighted: true)
    }
  }

  private func highlightNumbers(in attributedString: NSMutableAttributedString, text: String) {
    // Match integers, floats, and scientific notation
    let numberPattern = #"\b-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?\b"#
    applyPattern(
      numberPattern, to: attributedString, text: text, color: colors.number,
      skipIfAlreadyHighlighted: true)
  }

  private func highlightOperators(in attributedString: NSMutableAttributedString, text: String) {
    // Match OpenSCAD operators
    let operatorPattern = #"[+\-*/%<>=!&|?:]+"#
    applyPattern(
      operatorPattern, to: attributedString, text: text, color: colors.operator,
      skipIfAlreadyHighlighted: true)
  }

  // MARK: - Pattern Application

  enum HighlightPriority {
    case normal
    case high
  }

  private func applyPattern(
    _ pattern: String,
    to attributedString: NSMutableAttributedString,
    text: String,
    color: NSColor,
    priority: HighlightPriority = .normal,
    skipIfAlreadyHighlighted: Bool = false
  ) {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

    let range = NSRange(location: 0, length: text.utf16.count)
    let matches = regex.matches(in: text, options: [], range: range)

    for match in matches {
      let matchRange = match.range

      // Check if this range is already highlighted with a high-priority token (comment or string)
      if skipIfAlreadyHighlighted && isRangeHighlighted(matchRange, in: attributedString) {
        continue
      }

      attributedString.addAttribute(.foregroundColor, value: color, range: matchRange)

      // Mark high-priority tokens
      if priority == .high {
        attributedString.addAttribute(.init("SyntaxHighlighted"), value: true, range: matchRange)
      }
    }
  }

  private func isRangeHighlighted(_ range: NSRange, in attributedString: NSMutableAttributedString)
    -> Bool
  {
    guard range.location < attributedString.length else { return false }

    let attributes = attributedString.attributes(at: range.location, effectiveRange: nil)
    return attributes[.init("SyntaxHighlighted")] != nil
  }
}
