import Foundation

/// A code completion provider for OpenSCAD that suggests keywords, functions,
/// and special variables based on the current editing context.
final class CodeCompletionProvider {

  // MARK: - Completion Item

  /// Represents a single completion suggestion
  struct CompletionItem: Hashable, Identifiable {
    let id = UUID()
    let text: String
    let displayText: String
    let category: Category
    let insertText: String
    let detail: String?

    enum Category: String, CaseIterable {
      case keyword = "Keyword"
      case primitive = "Primitive"
      case transformation = "Transformation"
      case csgOperation = "CSG Operation"
      case mathFunction = "Math Function"
      case listStringFunction = "List/String Function"
      case specialVariable = "Special Variable"

      var icon: String {
        switch self {
        case .keyword: return "k"
        case .primitive: return "P"
        case .transformation: return "T"
        case .csgOperation: return "C"
        case .mathFunction: return "M"
        case .listStringFunction: return "F"
        case .specialVariable: return "$"
        }
      }
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(text)
      hasher.combine(category)
    }

    static func == (lhs: CompletionItem, rhs: CompletionItem) -> Bool {
      lhs.text == rhs.text && lhs.category == rhs.category
    }
  }

  // MARK: - Completion Items Database

  /// All available completion items, lazily initialized
  private lazy var allCompletionItems: [CompletionItem] = buildCompletionItems()

  // MARK: - Public Methods

  /// Get completion suggestions for the given partial word
  /// - Parameters:
  ///   - prefix: The partial word to complete (can be empty for showing all suggestions)
  ///   - limit: Maximum number of suggestions to return
  /// - Returns: Array of matching completion items, sorted by relevance
  func completions(for prefix: String, limit: Int = 20) -> [CompletionItem] {
    let lowercasedPrefix = prefix.lowercased()

    if lowercasedPrefix.isEmpty {
      return Array(allCompletionItems.prefix(limit))
    }

    // Filter and score completions
    let scored = allCompletionItems.compactMap { item -> (item: CompletionItem, score: Int)? in
      let lowercasedText = item.text.lowercased()

      // Exact prefix match - highest score
      if lowercasedText.hasPrefix(lowercasedPrefix) {
        let score = 1000 - item.text.count  // Shorter matches ranked higher
        return (item, score)
      }

      // Contains match - lower score
      if lowercasedText.contains(lowercasedPrefix) {
        let score = 500 - item.text.count
        return (item, score)
      }

      return nil
    }

    // Sort by score (higher is better) and return
    return
      scored
      .sorted { $0.score > $1.score }
      .prefix(limit)
      .map { $0.item }
  }

  /// Extract the partial word at the cursor position from the given text
  /// - Parameters:
  ///   - text: The full text
  ///   - cursorPosition: The cursor position (character index)
  /// - Returns: A tuple containing the partial word and its start position, or nil if no word
  func extractPartialWord(from text: String, at cursorPosition: Int) -> (
    word: String, startIndex: Int
  )? {
    guard cursorPosition > 0, cursorPosition <= text.count else {
      return nil
    }

    let index = text.index(text.startIndex, offsetBy: cursorPosition)
    var startIndex = index

    // Walk backwards to find the start of the word
    while startIndex > text.startIndex {
      let prevIndex = text.index(before: startIndex)
      let char = text[prevIndex]

      // Valid identifier characters in OpenSCAD: letters, digits, underscore, $
      if char.isLetter || char.isNumber || char == "_" || char == "$" {
        startIndex = prevIndex
      } else {
        break
      }
    }

    if startIndex == index {
      return nil  // No partial word
    }

    let word = String(text[startIndex..<index])
    let startOffset = text.distance(from: text.startIndex, to: startIndex)
    return (word, startOffset)
  }

  /// Check if completion should be triggered at the current position
  /// - Parameters:
  ///   - text: The full text
  ///   - cursorPosition: The cursor position
  /// - Returns: True if completions should be shown
  func shouldTriggerCompletion(in text: String, at cursorPosition: Int) -> Bool {
    guard let (word, _) = extractPartialWord(from: text, at: cursorPosition) else {
      return false
    }

    // Trigger completion if we have at least 1 character
    // For special variables starting with $, trigger immediately
    if word.hasPrefix("$") {
      return word.count >= 1
    }

    return word.count >= 1
  }

  // MARK: - Private Methods

  private func buildCompletionItems() -> [CompletionItem] {
    var items: [CompletionItem] = []

    // Keywords
    let keywordDetails: [String: String] = [
      "module": "Define a reusable module",
      "function": "Define a function that returns a value",
      "if": "Conditional statement",
      "else": "Alternative branch for if statement",
      "for": "Loop iteration",
      "let": "Local variable assignment",
      "each": "Iterate over list elements",
      "assert": "Assert a condition",
      "echo": "Print debug output",
      "use": "Import a library file",
      "include": "Include another file",
      "true": "Boolean true value",
      "false": "Boolean false value",
      "undef": "Undefined value",
    ]

    for keyword in OpenSCADSyntaxHighlighter.keywords {
      items.append(
        CompletionItem(
          text: keyword,
          displayText: keyword,
          category: .keyword,
          insertText: keyword,
          detail: keywordDetails[keyword]
        ))
    }

    // Primitives with parameter hints
    let primitiveDetails: [String: (insert: String, detail: String)] = [
      "cube": ("cube([x, y, z])", "Create a cube or rectangular box"),
      "sphere": ("sphere(r = radius)", "Create a sphere"),
      "cylinder": ("cylinder(h = height, r = radius)", "Create a cylinder"),
      "polyhedron": (
        "polyhedron(points = [], faces = [])", "Create a polyhedron from points and faces"
      ),
      "circle": ("circle(r = radius)", "Create a 2D circle"),
      "square": ("square([x, y])", "Create a 2D square or rectangle"),
      "polygon": ("polygon(points = [])", "Create a 2D polygon from points"),
      "text": ("text(\"string\")", "Create 2D text"),
    ]

    for primitive in OpenSCADSyntaxHighlighter.primitives {
      let info = primitiveDetails[primitive] ?? (primitive + "()", "Built-in primitive")
      items.append(
        CompletionItem(
          text: primitive,
          displayText: primitive,
          category: .primitive,
          insertText: info.insert,
          detail: info.detail
        ))
    }

    // Transformations
    let transformDetails: [String: (insert: String, detail: String)] = [
      "translate": ("translate([x, y, z])", "Move objects by offset"),
      "rotate": ("rotate([x, y, z])", "Rotate objects by angles"),
      "scale": ("scale([x, y, z])", "Scale objects by factors"),
      "mirror": ("mirror([x, y, z])", "Mirror objects across a plane"),
      "multmatrix": ("multmatrix(m)", "Apply transformation matrix"),
      "color": ("color(\"colorname\")", "Set object color"),
      "offset": ("offset(r = radius)", "Offset 2D shapes"),
      "hull": ("hull()", "Create convex hull of children"),
      "minkowski": ("minkowski()", "Minkowski sum of children"),
      "linear_extrude": ("linear_extrude(height = h)", "Extrude 2D shape linearly"),
      "rotate_extrude": ("rotate_extrude()", "Extrude 2D shape by rotation"),
      "surface": ("surface(file = \"file.dat\")", "Create surface from data file"),
      "projection": ("projection(cut = false)", "Project 3D to 2D"),
      "resize": ("resize([x, y, z])", "Resize objects to specific dimensions"),
      "render": ("render()", "Force rendering"),
      "children": ("children()", "Access child objects in module"),
    ]

    for transform in OpenSCADSyntaxHighlighter.transformations {
      let info = transformDetails[transform] ?? (transform + "()", "Built-in transformation")
      items.append(
        CompletionItem(
          text: transform,
          displayText: transform,
          category: .transformation,
          insertText: info.insert,
          detail: info.detail
        ))
    }

    // CSG Operations
    let csgDetails: [String: String] = [
      "union": "Combine multiple objects into one",
      "difference": "Subtract subsequent objects from the first",
      "intersection": "Keep only overlapping parts",
    ]

    for op in OpenSCADSyntaxHighlighter.csgOperations {
      items.append(
        CompletionItem(
          text: op,
          displayText: op,
          category: .csgOperation,
          insertText: op + "()",
          detail: csgDetails[op]
        ))
    }

    // Math Functions
    let mathDetails: [String: String] = [
      "abs": "Absolute value",
      "sign": "Sign of a number (-1, 0, or 1)",
      "sin": "Sine (degrees)",
      "cos": "Cosine (degrees)",
      "tan": "Tangent (degrees)",
      "acos": "Arc cosine (returns degrees)",
      "asin": "Arc sine (returns degrees)",
      "atan": "Arc tangent (returns degrees)",
      "atan2": "Two-argument arc tangent",
      "floor": "Round down to nearest integer",
      "round": "Round to nearest integer",
      "ceil": "Round up to nearest integer",
      "ln": "Natural logarithm",
      "log": "Logarithm base 10",
      "pow": "Power function",
      "sqrt": "Square root",
      "exp": "Exponential function",
      "rands": "Generate random numbers",
      "min": "Minimum of values",
      "max": "Maximum of values",
      "norm": "Vector norm (length)",
      "cross": "Cross product of vectors",
    ]

    for func_ in OpenSCADSyntaxHighlighter.mathFunctions {
      items.append(
        CompletionItem(
          text: func_,
          displayText: func_,
          category: .mathFunction,
          insertText: func_ + "()",
          detail: mathDetails[func_]
        ))
    }

    // List/String Functions
    let listStringDetails: [String: String] = [
      "concat": "Concatenate lists or strings",
      "lookup": "Lookup value in table",
      "str": "Convert to string",
      "chr": "Character from code point",
      "ord": "Code point from character",
      "search": "Search for value in list",
      "version": "OpenSCAD version as list",
      "version_num": "OpenSCAD version as number",
      "len": "Length of list or string",
      "parent_module": "Name of parent module",
      "is_undef": "Check if value is undefined",
      "is_bool": "Check if value is boolean",
      "is_num": "Check if value is a number",
      "is_string": "Check if value is a string",
      "is_list": "Check if value is a list",
      "is_function": "Check if value is a function",
    ]

    for func_ in OpenSCADSyntaxHighlighter.listStringFunctions {
      items.append(
        CompletionItem(
          text: func_,
          displayText: func_,
          category: .listStringFunction,
          insertText: func_ + "()",
          detail: listStringDetails[func_]
        ))
    }

    // Special Variables
    let specialVarDetails: [String: String] = [
      "$fn": "Number of fragments for circles/spheres",
      "$fa": "Minimum angle for fragments",
      "$fs": "Minimum size for fragments",
      "$t": "Animation time (0 to 1)",
      "$vpr": "Viewport rotation",
      "$vpt": "Viewport translation",
      "$vpd": "Viewport distance",
      "$vpf": "Viewport field of view",
      "$children": "Number of child objects in module",
      "$preview": "True in preview mode, false in render",
    ]

    for varName in OpenSCADSyntaxHighlighter.specialVariablePatterns {
      items.append(
        CompletionItem(
          text: varName,
          displayText: varName,
          category: .specialVariable,
          insertText: varName,
          detail: specialVarDetails[varName]
        ))
    }

    return items
  }
}
