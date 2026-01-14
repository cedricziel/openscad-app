import Foundation

/// Represents a completion item that can be suggested to the user
struct CompletionItem: Identifiable, Equatable {
  let id = UUID()
  let label: String
  let insertText: String
  let kind: CompletionItemKind
  let documentation: String?

  init(
    label: String, insertText: String? = nil, kind: CompletionItemKind, documentation: String? = nil
  ) {
    self.label = label
    self.insertText = insertText ?? label
    self.kind = kind
    self.documentation = documentation
  }

  static func == (lhs: CompletionItem, rhs: CompletionItem) -> Bool {
    lhs.label == rhs.label && lhs.kind == rhs.kind
  }
}

/// The kind of completion item, used for categorization and icon display
enum CompletionItemKind: String, CaseIterable {
  case keyword
  case function
  case module
  case variable
  case snippet

  var icon: String {
    switch self {
    case .keyword: return "k"
    case .function: return "ƒ"
    case .module: return "m"
    case .variable: return "$"
    case .snippet: return "⌘"
    }
  }
}

/// Provides code completion suggestions for OpenSCAD code
final class OpenSCADCompletionProvider {

  // MARK: - Completion Items

  /// All available completion items
  private(set) lazy var allCompletions: [CompletionItem] = {
    var items: [CompletionItem] = []

    // Keywords
    items.append(contentsOf: keywords)

    // 3D Primitives
    items.append(contentsOf: primitives3D)

    // 2D Primitives
    items.append(contentsOf: primitives2D)

    // Transformations
    items.append(contentsOf: transformations)

    // CSG Operations
    items.append(contentsOf: csgOperations)

    // Math Functions
    items.append(contentsOf: mathFunctions)

    // List/String Functions
    items.append(contentsOf: listStringFunctions)

    // Special Variables
    items.append(contentsOf: specialVariables)

    // Snippets
    items.append(contentsOf: snippets)

    return items
  }()

  // MARK: - Keywords

  private var keywords: [CompletionItem] {
    [
      CompletionItem(
        label: "module",
        insertText: "module name() {\n    \n}",
        kind: .keyword,
        documentation: "Defines a reusable module"
      ),
      CompletionItem(
        label: "function",
        insertText: "function name(x) = ",
        kind: .keyword,
        documentation: "Defines a function that returns a value"
      ),
      CompletionItem(
        label: "if",
        insertText: "if (condition) {\n    \n}",
        kind: .keyword,
        documentation: "Conditional statement"
      ),
      CompletionItem(
        label: "else",
        kind: .keyword,
        documentation: "Alternative branch of an if statement"
      ),
      CompletionItem(
        label: "for",
        insertText: "for (i = [0:10]) {\n    \n}",
        kind: .keyword,
        documentation: "Loop over a range or list"
      ),
      CompletionItem(
        label: "let",
        insertText: "let (x = value)",
        kind: .keyword,
        documentation: "Local variable assignment"
      ),
      CompletionItem(
        label: "each",
        kind: .keyword,
        documentation: "Flattens one level of nesting in list comprehension"
      ),
      CompletionItem(
        label: "assert",
        insertText: "assert(condition, \"message\")",
        kind: .keyword,
        documentation: "Asserts a condition is true"
      ),
      CompletionItem(
        label: "echo",
        insertText: "echo(\"message\")",
        kind: .keyword,
        documentation: "Outputs a message to the console"
      ),
      CompletionItem(
        label: "use",
        insertText: "use <filename.scad>",
        kind: .keyword,
        documentation: "Imports modules and functions from another file"
      ),
      CompletionItem(
        label: "include",
        insertText: "include <filename.scad>",
        kind: .keyword,
        documentation: "Includes another file's content"
      ),
      CompletionItem(
        label: "true",
        kind: .keyword,
        documentation: "Boolean true value"
      ),
      CompletionItem(
        label: "false",
        kind: .keyword,
        documentation: "Boolean false value"
      ),
      CompletionItem(
        label: "undef",
        kind: .keyword,
        documentation: "Undefined value"
      ),
    ]
  }

  // MARK: - 3D Primitives

  private var primitives3D: [CompletionItem] {
    [
      CompletionItem(
        label: "cube",
        insertText: "cube([10, 10, 10])",
        kind: .function,
        documentation:
          "Creates a cube or rectangular prism. Parameters: size (number or [x,y,z]), center (boolean)"
      ),
      CompletionItem(
        label: "sphere",
        insertText: "sphere(r = 10)",
        kind: .function,
        documentation: "Creates a sphere. Parameters: r (radius) or d (diameter)"
      ),
      CompletionItem(
        label: "cylinder",
        insertText: "cylinder(h = 10, r = 5)",
        kind: .function,
        documentation:
          "Creates a cylinder or cone. Parameters: h (height), r/r1/r2 (radius), d/d1/d2 (diameter), center"
      ),
      CompletionItem(
        label: "polyhedron",
        insertText: "polyhedron(points = [], faces = [])",
        kind: .function,
        documentation: "Creates a polyhedron from points and faces"
      ),
    ]
  }

  // MARK: - 2D Primitives

  private var primitives2D: [CompletionItem] {
    [
      CompletionItem(
        label: "circle",
        insertText: "circle(r = 10)",
        kind: .function,
        documentation: "Creates a 2D circle. Parameters: r (radius) or d (diameter)"
      ),
      CompletionItem(
        label: "square",
        insertText: "square([10, 10])",
        kind: .function,
        documentation:
          "Creates a 2D square or rectangle. Parameters: size (number or [x,y]), center"
      ),
      CompletionItem(
        label: "polygon",
        insertText: "polygon(points = [])",
        kind: .function,
        documentation: "Creates a 2D polygon from points"
      ),
      CompletionItem(
        label: "text",
        insertText: "text(\"text\", size = 10)",
        kind: .function,
        documentation: "Creates 2D text. Parameters: text, size, font, halign, valign, spacing"
      ),
    ]
  }

  // MARK: - Transformations

  private var transformations: [CompletionItem] {
    [
      CompletionItem(
        label: "translate",
        insertText: "translate([0, 0, 0])",
        kind: .function,
        documentation: "Moves children by the specified offset [x, y, z]"
      ),
      CompletionItem(
        label: "rotate",
        insertText: "rotate([0, 0, 0])",
        kind: .function,
        documentation: "Rotates children by specified angles [x, y, z] in degrees"
      ),
      CompletionItem(
        label: "scale",
        insertText: "scale([1, 1, 1])",
        kind: .function,
        documentation: "Scales children by specified factors [x, y, z]"
      ),
      CompletionItem(
        label: "mirror",
        insertText: "mirror([1, 0, 0])",
        kind: .function,
        documentation: "Mirrors children across a plane defined by the normal vector"
      ),
      CompletionItem(
        label: "multmatrix",
        insertText: "multmatrix(m = [[1,0,0,0],[0,1,0,0],[0,0,1,0]])",
        kind: .function,
        documentation: "Applies a 4x4 transformation matrix"
      ),
      CompletionItem(
        label: "color",
        insertText: "color(\"red\")",
        kind: .function,
        documentation: "Sets the color of children. Can use color name or [r,g,b,a]"
      ),
      CompletionItem(
        label: "offset",
        insertText: "offset(r = 1)",
        kind: .function,
        documentation: "Offsets 2D outlines. Parameters: r (radius), delta, chamfer"
      ),
      CompletionItem(
        label: "hull",
        insertText: "hull() {\n    \n}",
        kind: .function,
        documentation: "Creates convex hull of children"
      ),
      CompletionItem(
        label: "minkowski",
        insertText: "minkowski() {\n    \n}",
        kind: .function,
        documentation: "Minkowski sum of children"
      ),
      CompletionItem(
        label: "linear_extrude",
        insertText: "linear_extrude(height = 10)",
        kind: .function,
        documentation:
          "Extrudes 2D shapes along the Z axis. Parameters: height, center, twist, slices, scale"
      ),
      CompletionItem(
        label: "rotate_extrude",
        insertText: "rotate_extrude(angle = 360)",
        kind: .function,
        documentation: "Rotates 2D shapes around the Z axis. Parameters: angle, convexity"
      ),
      CompletionItem(
        label: "surface",
        insertText: "surface(file = \"heightmap.png\")",
        kind: .function,
        documentation: "Creates a surface from a heightmap file"
      ),
      CompletionItem(
        label: "projection",
        insertText: "projection(cut = false)",
        kind: .function,
        documentation: "Projects 3D objects to 2D. Parameters: cut"
      ),
      CompletionItem(
        label: "resize",
        insertText: "resize([10, 10, 10])",
        kind: .function,
        documentation: "Resizes children to exact dimensions"
      ),
      CompletionItem(
        label: "render",
        insertText: "render(convexity = 1)",
        kind: .function,
        documentation: "Forces rendering of children for preview"
      ),
      CompletionItem(
        label: "children",
        insertText: "children()",
        kind: .function,
        documentation: "References child nodes passed to a module"
      ),
    ]
  }

  // MARK: - CSG Operations

  private var csgOperations: [CompletionItem] {
    [
      CompletionItem(
        label: "union",
        insertText: "union() {\n    \n}",
        kind: .function,
        documentation: "Combines multiple shapes into one"
      ),
      CompletionItem(
        label: "difference",
        insertText: "difference() {\n    \n}",
        kind: .function,
        documentation: "Subtracts subsequent shapes from the first shape"
      ),
      CompletionItem(
        label: "intersection",
        insertText: "intersection() {\n    \n}",
        kind: .function,
        documentation: "Creates the intersection of all shapes"
      ),
    ]
  }

  // MARK: - Math Functions

  private var mathFunctions: [CompletionItem] {
    [
      CompletionItem(
        label: "abs", insertText: "abs(x)", kind: .function, documentation: "Absolute value"),
      CompletionItem(
        label: "sign", insertText: "sign(x)", kind: .function,
        documentation: "Sign of value (-1, 0, or 1)"),
      CompletionItem(
        label: "sin", insertText: "sin(x)", kind: .function,
        documentation: "Sine (argument in degrees)"),
      CompletionItem(
        label: "cos", insertText: "cos(x)", kind: .function,
        documentation: "Cosine (argument in degrees)"),
      CompletionItem(
        label: "tan", insertText: "tan(x)", kind: .function,
        documentation: "Tangent (argument in degrees)"),
      CompletionItem(
        label: "acos", insertText: "acos(x)", kind: .function,
        documentation: "Arc cosine (returns degrees)"),
      CompletionItem(
        label: "asin", insertText: "asin(x)", kind: .function,
        documentation: "Arc sine (returns degrees)"),
      CompletionItem(
        label: "atan", insertText: "atan(x)", kind: .function,
        documentation: "Arc tangent (returns degrees)"),
      CompletionItem(
        label: "atan2", insertText: "atan2(y, x)", kind: .function,
        documentation: "Two-argument arc tangent"),
      CompletionItem(
        label: "floor", insertText: "floor(x)", kind: .function,
        documentation: "Largest integer not greater than x"),
      CompletionItem(
        label: "round", insertText: "round(x)", kind: .function,
        documentation: "Round to nearest integer"),
      CompletionItem(
        label: "ceil", insertText: "ceil(x)", kind: .function,
        documentation: "Smallest integer not less than x"),
      CompletionItem(
        label: "ln", insertText: "ln(x)", kind: .function, documentation: "Natural logarithm"),
      CompletionItem(
        label: "log", insertText: "log(x)", kind: .function, documentation: "Logarithm base 10"),
      CompletionItem(
        label: "pow", insertText: "pow(base, exponent)", kind: .function,
        documentation: "Power function"),
      CompletionItem(
        label: "sqrt", insertText: "sqrt(x)", kind: .function, documentation: "Square root"),
      CompletionItem(
        label: "exp", insertText: "exp(x)", kind: .function,
        documentation: "Exponential function (e^x)"),
      CompletionItem(
        label: "rands", insertText: "rands(min, max, count)", kind: .function,
        documentation: "Random number vector"),
      CompletionItem(
        label: "min", insertText: "min(a, b)", kind: .function, documentation: "Minimum value"),
      CompletionItem(
        label: "max", insertText: "max(a, b)", kind: .function, documentation: "Maximum value"),
      CompletionItem(
        label: "norm", insertText: "norm(v)", kind: .function,
        documentation: "Euclidean norm of a vector"),
      CompletionItem(
        label: "cross", insertText: "cross(a, b)", kind: .function,
        documentation: "Cross product of two vectors"),
    ]
  }

  // MARK: - List/String Functions

  private var listStringFunctions: [CompletionItem] {
    [
      CompletionItem(
        label: "concat", insertText: "concat(a, b)", kind: .function,
        documentation: "Concatenates lists or values"),
      CompletionItem(
        label: "lookup", insertText: "lookup(key, table)", kind: .function,
        documentation: "Looks up a value in a table"),
      CompletionItem(
        label: "str", insertText: "str(value)", kind: .function,
        documentation: "Converts values to string"),
      CompletionItem(
        label: "chr", insertText: "chr(code)", kind: .function,
        documentation: "Converts code point to character"),
      CompletionItem(
        label: "ord", insertText: "ord(char)", kind: .function,
        documentation: "Converts character to code point"),
      CompletionItem(
        label: "search", insertText: "search(needle, haystack)", kind: .function,
        documentation: "Searches for values in a list"),
      CompletionItem(
        label: "version", insertText: "version()", kind: .function,
        documentation: "Returns OpenSCAD version as list"),
      CompletionItem(
        label: "version_num", insertText: "version_num()", kind: .function,
        documentation: "Returns OpenSCAD version as number"),
      CompletionItem(
        label: "len", insertText: "len(value)", kind: .function,
        documentation: "Length of string or list"),
      CompletionItem(
        label: "parent_module", insertText: "parent_module(idx)", kind: .function,
        documentation: "Returns name of parent module"),
      CompletionItem(
        label: "is_undef", insertText: "is_undef(value)", kind: .function,
        documentation: "Checks if value is undefined"),
      CompletionItem(
        label: "is_bool", insertText: "is_bool(value)", kind: .function,
        documentation: "Checks if value is boolean"),
      CompletionItem(
        label: "is_num", insertText: "is_num(value)", kind: .function,
        documentation: "Checks if value is a number"),
      CompletionItem(
        label: "is_string", insertText: "is_string(value)", kind: .function,
        documentation: "Checks if value is a string"),
      CompletionItem(
        label: "is_list", insertText: "is_list(value)", kind: .function,
        documentation: "Checks if value is a list"),
      CompletionItem(
        label: "is_function", insertText: "is_function(value)", kind: .function,
        documentation: "Checks if value is a function"),
    ]
  }

  // MARK: - Special Variables

  private var specialVariables: [CompletionItem] {
    [
      CompletionItem(
        label: "$fn",
        insertText: "$fn = 100",
        kind: .variable,
        documentation: "Number of fragments for circles/spheres. Higher = smoother"
      ),
      CompletionItem(
        label: "$fa",
        insertText: "$fa = 1",
        kind: .variable,
        documentation: "Minimum angle for fragments (degrees)"
      ),
      CompletionItem(
        label: "$fs",
        insertText: "$fs = 0.5",
        kind: .variable,
        documentation: "Minimum size of fragments"
      ),
      CompletionItem(
        label: "$t",
        kind: .variable,
        documentation: "Animation time variable (0 to 1)"
      ),
      CompletionItem(
        label: "$vpr",
        kind: .variable,
        documentation: "Viewport rotation [x, y, z]"
      ),
      CompletionItem(
        label: "$vpt",
        kind: .variable,
        documentation: "Viewport translation [x, y, z]"
      ),
      CompletionItem(
        label: "$vpd",
        kind: .variable,
        documentation: "Viewport camera distance"
      ),
      CompletionItem(
        label: "$vpf",
        kind: .variable,
        documentation: "Viewport field of view"
      ),
      CompletionItem(
        label: "$children",
        kind: .variable,
        documentation: "Number of children in current module"
      ),
      CompletionItem(
        label: "$preview",
        kind: .variable,
        documentation: "True if in preview mode, false if rendering"
      ),
    ]
  }

  // MARK: - Snippets

  private var snippets: [CompletionItem] {
    [
      CompletionItem(
        label: "module_template",
        insertText: """
          module name(size = 10) {
              // Module implementation
              cube([size, size, size]);
          }
          """,
        kind: .snippet,
        documentation: "Template for a new module"
      ),
      CompletionItem(
        label: "rounded_cube",
        insertText: """
          module rounded_cube(size, radius) {
              hull() {
                  for (x = [radius, size[0] - radius])
                      for (y = [radius, size[1] - radius])
                          for (z = [radius, size[2] - radius])
                              translate([x, y, z])
                                  sphere(r = radius);
              }
          }
          """,
        kind: .snippet,
        documentation: "Creates a cube with rounded corners"
      ),
      CompletionItem(
        label: "loop_circle",
        insertText: """
          for (i = [0:n-1]) {
              rotate([0, 0, i * 360 / n])
                  translate([radius, 0, 0])
                      child();
          }
          """,
        kind: .snippet,
        documentation: "Distributes objects in a circular pattern"
      ),
    ]
  }

  // MARK: - Completion Methods

  /// Returns completions that match the given prefix
  /// - Parameter prefix: The text prefix to match against
  /// - Returns: Array of matching completion items, sorted by relevance
  func completions(for prefix: String) -> [CompletionItem] {
    guard !prefix.isEmpty else { return [] }

    let lowercasedPrefix = prefix.lowercased()

    // Filter completions that match the prefix
    let matches = allCompletions.filter { item in
      item.label.lowercased().hasPrefix(lowercasedPrefix)
    }

    // Sort by: exact match first, then by label length, then alphabetically
    return matches.sorted { a, b in
      let aExact = a.label.lowercased() == lowercasedPrefix
      let bExact = b.label.lowercased() == lowercasedPrefix

      if aExact != bExact {
        return aExact
      }

      if a.label.count != b.label.count {
        return a.label.count < b.label.count
      }

      return a.label < b.label
    }
  }

  /// Extracts the word being typed at the current cursor position
  /// - Parameters:
  ///   - text: The full text content
  ///   - cursorPosition: The cursor position in the text
  /// - Returns: The word prefix being typed, or nil if not applicable
  func extractPrefix(from text: String, at cursorPosition: Int) -> String? {
    guard cursorPosition > 0, cursorPosition <= text.count else { return nil }

    let textUpToCursor = String(text.prefix(cursorPosition))

    // Find the start of the current word
    var wordStart = textUpToCursor.endIndex
    for index in textUpToCursor.indices.reversed() {
      let char = textUpToCursor[index]
      if char.isLetter || char.isNumber || char == "_" || char == "$" {
        wordStart = index
      } else {
        break
      }
    }

    let prefix = String(textUpToCursor[wordStart...])

    // Only return prefix if it's at least 1 character
    return prefix.count >= 1 ? prefix : nil
  }
}
