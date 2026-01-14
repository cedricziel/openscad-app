import AppKit
import Foundation

/// Represents a single code completion suggestion
struct CompletionItem: Identifiable, Equatable {
  let id = UUID()
  let text: String
  let displayText: String
  let category: CompletionCategory
  let insertionText: String
  let documentation: String?

  static func == (lhs: CompletionItem, rhs: CompletionItem) -> Bool {
    lhs.text == rhs.text && lhs.category == rhs.category
  }
}

/// Categories for completion items
enum CompletionCategory: String, CaseIterable {
  case keyword = "Keyword"
  case primitive = "Primitive"
  case transformation = "Transformation"
  case csgOperation = "CSG Operation"
  case mathFunction = "Math Function"
  case listFunction = "List/String Function"
  case specialVariable = "Special Variable"
  case userDefined = "User Defined"

  var icon: String {
    switch self {
    case .keyword: return "k"
    case .primitive: return "P"
    case .transformation: return "T"
    case .csgOperation: return "C"
    case .mathFunction: return "f"
    case .listFunction: return "f"
    case .specialVariable: return "$"
    case .userDefined: return "u"
    }
  }

  var color: NSColor {
    switch self {
    case .keyword: return .systemPurple
    case .primitive: return .systemBlue
    case .transformation: return .systemBlue
    case .csgOperation: return .systemBlue
    case .mathFunction: return .systemOrange
    case .listFunction: return .systemOrange
    case .specialVariable: return .systemTeal
    case .userDefined: return .systemGray
    }
  }
}

/// Provides code completion suggestions for OpenSCAD code
final class OpenSCADCompletionProvider {

  // MARK: - Static Completion Items

  /// All built-in completion items
  private static let builtinCompletions: [CompletionItem] = {
    var items: [CompletionItem] = []

    // Keywords
    items += OpenSCADSyntaxHighlighter.keywords.map { keyword in
      CompletionItem(
        text: keyword,
        displayText: keyword,
        category: .keyword,
        insertionText: keywordInsertionText(for: keyword),
        documentation: keywordDocumentation(for: keyword)
      )
    }

    // Primitives
    items += OpenSCADSyntaxHighlighter.primitives.map { primitive in
      CompletionItem(
        text: primitive,
        displayText: "\(primitive)()",
        category: .primitive,
        insertionText: primitiveInsertionText(for: primitive),
        documentation: primitiveDocumentation(for: primitive)
      )
    }

    // Transformations
    items += OpenSCADSyntaxHighlighter.transformations.map { transform in
      CompletionItem(
        text: transform,
        displayText: "\(transform)()",
        category: .transformation,
        insertionText: transformationInsertionText(for: transform),
        documentation: transformationDocumentation(for: transform)
      )
    }

    // CSG Operations
    items += OpenSCADSyntaxHighlighter.csgOperations.map { operation in
      CompletionItem(
        text: operation,
        displayText: "\(operation)()",
        category: .csgOperation,
        insertionText: "\(operation)() {\n    \n}",
        documentation: csgDocumentation(for: operation)
      )
    }

    // Math Functions
    items += OpenSCADSyntaxHighlighter.mathFunctions.map { function in
      CompletionItem(
        text: function,
        displayText: "\(function)()",
        category: .mathFunction,
        insertionText: "\(function)()",
        documentation: mathFunctionDocumentation(for: function)
      )
    }

    // List/String Functions
    items += OpenSCADSyntaxHighlighter.listStringFunctions.map { function in
      CompletionItem(
        text: function,
        displayText: "\(function)()",
        category: .listFunction,
        insertionText: "\(function)()",
        documentation: listFunctionDocumentation(for: function)
      )
    }

    // Special Variables
    items += OpenSCADSyntaxHighlighter.specialVariablePatterns.map { variable in
      CompletionItem(
        text: variable,
        displayText: variable,
        category: .specialVariable,
        insertionText: variable,
        documentation: specialVariableDocumentation(for: variable)
      )
    }

    return items
  }()

  // MARK: - Public Methods

  /// Returns completion suggestions based on the current word prefix
  /// - Parameters:
  ///   - prefix: The current word being typed (the prefix to match)
  ///   - text: The full document text (used to extract user-defined symbols)
  ///   - maxResults: Maximum number of results to return
  /// - Returns: Array of completion items matching the prefix
  func completions(for prefix: String, in text: String, maxResults: Int = 20) -> [CompletionItem] {
    guard !prefix.isEmpty else { return [] }

    let lowercasedPrefix = prefix.lowercased()

    // Get matching built-in completions
    var matches = Self.builtinCompletions.filter { item in
      item.text.lowercased().hasPrefix(lowercasedPrefix)
    }

    // Add user-defined symbols from the current document
    let userDefinedItems = extractUserDefinedSymbols(from: text, matching: prefix)
    matches += userDefinedItems

    // Sort by relevance: exact prefix match first, then alphabetically
    matches.sort { item1, item2 in
      let text1 = item1.text.lowercased()
      let text2 = item2.text.lowercased()

      // Exact prefix matches come first
      let exact1 = text1.hasPrefix(lowercasedPrefix)
      let exact2 = text2.hasPrefix(lowercasedPrefix)

      if exact1 && !exact2 { return true }
      if !exact1 && exact2 { return false }

      // Then sort by category priority
      let priority1 = categoryPriority(item1.category)
      let priority2 = categoryPriority(item2.category)

      if priority1 != priority2 { return priority1 < priority2 }

      // Finally, sort alphabetically
      return text1 < text2
    }

    // Remove duplicates (prefer built-in over user-defined)
    var seen = Set<String>()
    matches = matches.filter { item in
      let key = item.text.lowercased()
      if seen.contains(key) { return false }
      seen.insert(key)
      return true
    }

    return Array(matches.prefix(maxResults))
  }

  /// Extracts the current word being typed at the given cursor position
  /// - Parameters:
  ///   - text: The full document text
  ///   - cursorPosition: The current cursor position (character index)
  /// - Returns: A tuple containing the word prefix and its range in the text
  func currentWordPrefix(in text: String, at cursorPosition: Int) -> (
    prefix: String, range: NSRange
  )? {
    guard cursorPosition > 0, cursorPosition <= text.count else { return nil }

    let nsText = text as NSString

    // Find the start of the current word
    var wordStart = cursorPosition
    while wordStart > 0 {
      let index = wordStart - 1
      let char = nsText.character(at: index)
      let scalar = UnicodeScalar(char)

      // Check if character is part of an identifier (alphanumeric, underscore, or $)
      if let scalar = scalar,
        CharacterSet.alphanumerics.contains(scalar) || char == UInt16(UInt8(ascii: "_"))
          || char == UInt16(UInt8(ascii: "$"))
      {
        wordStart -= 1
      } else {
        break
      }
    }

    guard wordStart < cursorPosition else { return nil }

    let range = NSRange(location: wordStart, length: cursorPosition - wordStart)
    let prefix = nsText.substring(with: range)

    // Don't provide completions for very short prefixes (except for $)
    if prefix.count < 2 && !prefix.hasPrefix("$") {
      return nil
    }

    return (prefix, range)
  }

  // MARK: - User-Defined Symbol Extraction

  /// Extracts user-defined modules, functions, and variables from the document
  private func extractUserDefinedSymbols(from text: String, matching prefix: String)
    -> [CompletionItem]
  {
    var items: [CompletionItem] = []

    // Extract module names: module name(...)
    let modulePattern = #"module\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\("#
    items += extractSymbols(
      from: text, pattern: modulePattern, category: .userDefined, prefix: prefix)

    // Extract function names: function name(...)
    let functionPattern = #"function\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\("#
    items +=
      extractSymbols(from: text, pattern: functionPattern, category: .userDefined, prefix: prefix)

    // Extract variable assignments: name = value
    let variablePattern = #"^\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*="#
    items +=
      extractSymbols(
        from: text, pattern: variablePattern, category: .userDefined, prefix: prefix,
        multiline: true)

    return items
  }

  private func extractSymbols(
    from text: String,
    pattern: String,
    category: CompletionCategory,
    prefix: String,
    multiline: Bool = false
  ) -> [CompletionItem] {
    var options: NSRegularExpression.Options = []
    if multiline {
      options.insert(.anchorsMatchLines)
    }

    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
      return []
    }

    let range = NSRange(location: 0, length: text.utf16.count)
    let matches = regex.matches(in: text, options: [], range: range)

    var items: [CompletionItem] = []
    var seen = Set<String>()

    for match in matches {
      guard match.numberOfRanges > 1,
        let symbolRange = Range(match.range(at: 1), in: text)
      else {
        continue
      }

      let symbol = String(text[symbolRange])

      // Skip if doesn't match prefix or already seen
      guard symbol.lowercased().hasPrefix(prefix.lowercased()),
        !seen.contains(symbol.lowercased())
      else {
        continue
      }

      seen.insert(symbol.lowercased())

      items.append(
        CompletionItem(
          text: symbol,
          displayText: symbol,
          category: category,
          insertionText: symbol,
          documentation: "User-defined symbol"
        ))
    }

    return items
  }

  // MARK: - Helper Methods

  private func categoryPriority(_ category: CompletionCategory) -> Int {
    switch category {
    case .keyword: return 0
    case .primitive: return 1
    case .transformation: return 2
    case .csgOperation: return 3
    case .mathFunction: return 4
    case .listFunction: return 5
    case .specialVariable: return 6
    case .userDefined: return 7
    }
  }

  // MARK: - Insertion Text Helpers

  private static func keywordInsertionText(for keyword: String) -> String {
    switch keyword {
    case "module": return "module name() {\n    \n}"
    case "function": return "function name() = "
    case "if": return "if () {\n    \n}"
    case "else": return "else {\n    \n}"
    case "for": return "for (i = [0:1:10]) {\n    \n}"
    case "let": return "let () "
    case "use": return "use <>"
    case "include": return "include <>"
    case "assert": return "assert(, \"\")"
    case "echo": return "echo()"
    default: return keyword
    }
  }

  private static func primitiveInsertionText(for primitive: String) -> String {
    switch primitive {
    case "cube": return "cube([10, 10, 10])"
    case "sphere": return "sphere(r = 5)"
    case "cylinder": return "cylinder(h = 10, r = 5)"
    case "polyhedron": return "polyhedron(points = [], faces = [])"
    case "circle": return "circle(r = 5)"
    case "square": return "square([10, 10])"
    case "polygon": return "polygon(points = [])"
    case "text": return "text(\"\")"
    default: return "\(primitive)()"
    }
  }

  private static func transformationInsertionText(for transform: String) -> String {
    switch transform {
    case "translate": return "translate([0, 0, 0])"
    case "rotate": return "rotate([0, 0, 0])"
    case "scale": return "scale([1, 1, 1])"
    case "mirror": return "mirror([1, 0, 0])"
    case "color": return "color(\"\")"
    case "linear_extrude": return "linear_extrude(height = 10)"
    case "rotate_extrude": return "rotate_extrude()"
    case "hull": return "hull() {\n    \n}"
    case "minkowski": return "minkowski() {\n    \n}"
    case "offset": return "offset(r = 1)"
    case "resize": return "resize([10, 10, 10])"
    case "multmatrix": return "multmatrix(m = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0]])"
    default: return "\(transform)()"
    }
  }

  // MARK: - Documentation Helpers

  private static func keywordDocumentation(for keyword: String) -> String {
    switch keyword {
    case "module": return "Defines a reusable module (like a function that creates geometry)"
    case "function": return "Defines a function that returns a value"
    case "if": return "Conditional statement"
    case "else": return "Alternative branch for conditional statement"
    case "for": return "Loop construct for iterating over ranges or lists"
    case "let": return "Assigns local variables within an expression"
    case "each": return "Flattens nested lists in list comprehensions"
    case "assert": return "Checks a condition and stops execution if false"
    case "echo": return "Prints values to the console for debugging"
    case "use": return "Imports modules and functions from another file"
    case "include": return "Includes all code from another file"
    case "true": return "Boolean true value"
    case "false": return "Boolean false value"
    case "undef": return "Undefined value"
    default: return "OpenSCAD keyword"
    }
  }

  private static func primitiveDocumentation(for primitive: String) -> String {
    switch primitive {
    case "cube": return "Creates a cube or rectangular prism. cube([x, y, z]) or cube(size)"
    case "sphere": return "Creates a sphere. sphere(r) or sphere(d)"
    case "cylinder":
      return "Creates a cylinder or cone. cylinder(h, r) or cylinder(h, r1, r2)"
    case "polyhedron": return "Creates an arbitrary polyhedron from points and faces"
    case "circle": return "Creates a 2D circle. circle(r) or circle(d)"
    case "square": return "Creates a 2D square or rectangle. square([x, y]) or square(size)"
    case "polygon": return "Creates a 2D polygon from a list of points"
    case "text": return "Creates 2D text geometry. text(\"string\", size, font)"
    default: return "OpenSCAD primitive"
    }
  }

  private static func transformationDocumentation(for transform: String) -> String {
    switch transform {
    case "translate": return "Moves objects. translate([x, y, z])"
    case "rotate": return "Rotates objects. rotate([x, y, z]) or rotate(a, v)"
    case "scale": return "Scales objects. scale([x, y, z]) or scale(s)"
    case "mirror": return "Mirrors objects across a plane. mirror([x, y, z])"
    case "multmatrix": return "Applies a 4x4 transformation matrix"
    case "color": return "Sets the color of objects. color(\"name\") or color([r, g, b, a])"
    case "offset": return "Expands or contracts 2D shapes. offset(r) or offset(delta)"
    case "hull": return "Creates the convex hull of child objects"
    case "minkowski": return "Computes the Minkowski sum of child objects"
    case "linear_extrude": return "Extrudes 2D shapes into 3D. linear_extrude(height)"
    case "rotate_extrude": return "Rotates 2D shapes around the Z axis to create 3D objects"
    case "surface": return "Creates a surface from a data file or function"
    case "projection": return "Projects 3D objects onto the XY plane"
    case "resize": return "Resizes objects to specific dimensions"
    case "render": return "Forces rendering of a subtree (useful for complex CSG)"
    case "children": return "Accesses child objects in a module"
    default: return "OpenSCAD transformation"
    }
  }

  private static func csgDocumentation(for operation: String) -> String {
    switch operation {
    case "union": return "Combines multiple objects into one"
    case "difference": return "Subtracts subsequent objects from the first"
    case "intersection": return "Keeps only the overlapping parts of objects"
    default: return "CSG operation"
    }
  }

  private static func mathFunctionDocumentation(for function: String) -> String {
    switch function {
    case "abs": return "Returns the absolute value"
    case "sign": return "Returns -1, 0, or 1 based on the sign"
    case "sin", "cos", "tan": return "Trigonometric function (angle in degrees)"
    case "asin", "acos", "atan": return "Inverse trigonometric function (returns degrees)"
    case "atan2": return "Two-argument arctangent. atan2(y, x)"
    case "floor": return "Rounds down to nearest integer"
    case "ceil": return "Rounds up to nearest integer"
    case "round": return "Rounds to nearest integer"
    case "ln": return "Natural logarithm"
    case "log": return "Logarithm base 10"
    case "pow": return "Power function. pow(base, exponent)"
    case "sqrt": return "Square root"
    case "exp": return "Exponential function (e^x)"
    case "rands": return "Generates random numbers. rands(min, max, count)"
    case "min": return "Returns the minimum value"
    case "max": return "Returns the maximum value"
    case "norm": return "Returns the Euclidean norm of a vector"
    case "cross": return "Returns the cross product of two 3D vectors"
    default: return "Math function"
    }
  }

  private static func listFunctionDocumentation(for function: String) -> String {
    switch function {
    case "concat": return "Concatenates lists or values"
    case "lookup": return "Looks up a value in a table. lookup(key, table)"
    case "str": return "Converts values to a string"
    case "chr": return "Converts a code point to a character"
    case "ord": return "Converts a character to its code point"
    case "search": return "Searches for values in a list or string"
    case "version": return "Returns OpenSCAD version as a list"
    case "version_num": return "Returns OpenSCAD version as a number"
    case "len": return "Returns the length of a list or string"
    case "parent_module": return "Returns the name of the parent module"
    case "is_undef": return "Returns true if the value is undefined"
    case "is_bool": return "Returns true if the value is a boolean"
    case "is_num": return "Returns true if the value is a number"
    case "is_string": return "Returns true if the value is a string"
    case "is_list": return "Returns true if the value is a list"
    case "is_function": return "Returns true if the value is a function"
    default: return "List/String function"
    }
  }

  private static func specialVariableDocumentation(for variable: String) -> String {
    switch variable {
    case "$fn": return "Number of fragments used to render curves (higher = smoother)"
    case "$fa": return "Minimum angle for each fragment"
    case "$fs": return "Minimum size of each fragment"
    case "$t": return "Animation time variable (0 to 1)"
    case "$vpr": return "Viewport rotation as [x, y, z] angles"
    case "$vpt": return "Viewport translation as [x, y, z]"
    case "$vpd": return "Viewport camera distance"
    case "$vpf": return "Viewport field of view"
    case "$children": return "Number of child objects in current module"
    case "$preview": return "True if in preview mode, false if rendering"
    default: return "Special variable"
    }
  }
}
