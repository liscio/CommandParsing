import Parsing

// MARK: Command Definitions

/// These commands are what you'd be "dispatching" in your application. For example, these could be your Events in the Composable Architecture.
enum Command: Equatable {
  case measureDistance(to: Bound, using: Unit, percentAccuracy: Int)
  case clearMeasurement(to: Bound)
  // ...
  enum Bound: String, CaseIterable, Equatable {
    case start
    case end
  }
  enum Unit: String, CaseIterable, Equatable {
    case inches
    case centimeters
  }
}

// MARK: The (exposed) command parser

struct CommandParserError: Error {}

struct CommandParser: Parser {
  let commandNames: [String]
  let commands: [String : AnyParser<Substring, Command>]
  
  init(commands: [String : AnyParser<Substring, Command>]) {
    self.commandNames = commands.sorted(by: { (lhs,rhs) in lhs.key < rhs.key }).map(\.0)
    self.commands = commands
  }
  
  let functionName = Parsers.Prefix { $0 != "(" && !$0.isNewline }
  let openBracket = Skip { "("; Prefix { $0.isWhitespace } }
  let closeBracket = Skip { Prefix { $0.isWhitespace }; ")" }

  /// Parse the given input, get a ``Command`` on output
  ///
  /// The method goes like this:
  ///
  /// A command's name is looked up in this hash table (very fast---especially for long lists!) to obtain its associated parser. This should be _far quicker_ than the `O(n)` linear search that you're running when you use a ``Parser.OneOfMany``, in practice.
  ///
  /// But it's not just about performance--when a command lookup fails, we can provide feedback about a potential misspelling of the command's name. In contrast, ``Parser.OneOfMany`` dumps the _entire dictionary_ of failed commands into the error.
  ///
  /// As for the "spell checking", that's an exercise for the reader. You'll probably want to match on the `commandNames`, use an edit distance algorithm, etc. :)
  func parse(_ input: inout Substring) throws -> Command {
    let theFunction: Substring
    do {
      theFunction = try functionName.parse(&input)
    } catch {
      // TODO: Didn't get a function name at all!
      throw CommandParserError()
    }
    
    if let innerParser = commands[String(theFunction)] {
      // Now we have the (recognized) function name, and can run its associated parser
      return try innerParser.parse(&input)
    } else {
      // We could not find the command among our list
      // TODO: Report the failed lookup, and---if found---provide the closest match from our list.
      throw CommandParserError()
    }
  }
}

extension CommandParser {
  static let `default` = Self(commands: makeCommandParsers())
}

// MARK: Command Parser Definitions

/// This is the list of supported (parseable) commands. Each textual description is paired with a "factory" that takes the parsed `CommandDescriptor` and spits out the command. See ``makeParser`` below to learn more.
fileprivate var parserDefinitions: [String:(CommandDescriptor) -> AnyParser<Substring,Command>] = [
  "measureDistance(to: Bound, using: Unit, percentAccuracy: Int)" : makeParser(for: Command.measureDistance),
  "clearMeasurement(to: Bound)" : makeParser(for: Command.clearMeasurement)
]

/// An intermediate type that describes a command. The textual parser definitions above are parsed into this descriptor type.
struct CommandDescriptor {
  var name: String
  var params: [ParameterDescriptor]
}

/// These are used by ``CommandDescriptor``, and include all the supported "kinds" of parameter types from your commands.
struct ParameterDescriptor {
  var name: String
  var kind: Kind
  
  enum Kind: String, CaseIterable {
    case bound = "Bound"
    case unit = "Unit"
    case integer = "Int"
  }
}

// MARK: Parser Factories

/// Return a factory function that produces ``Command`` parsers.
///
/// This is where most of the heavy lifting is done for this whole approach that I've come up with. It allows us to use a unified `Value` type in the ``parserDefinitions`` dictionary, and relies on overloading + type inference to match a ``Command`` case to its appropriate parser factory.
///
/// Put another way, "You tell me how to make a `Command`, and I'll give you a function that turns `CommandDescriptor`s into `Command` parsers."
fileprivate func makeParser(
  for f: @escaping (
    Command.Bound,
    Command.Unit,
    Int
  ) -> Command
) -> (CommandDescriptor) -> AnyParser<Substring, Command> {
  return { (desc: CommandDescriptor) -> AnyParser<Substring, Command> in
    assert(desc.params.count == 3)
    assert(desc.params[0].kind == .bound)
    assert(desc.params[1].kind == .unit)
    assert(desc.params[2].kind == .integer)
    
    return WithParameters {
      Parse(f) {
        Parameter(desc.params[0].name) { Command.Bound.parser() }
        Parameter(desc.params[1].name) { Command.Unit.parser() }
        Parameter(desc.params[2].name, isLast: true) { Int.parser() }
      }
    }.eraseToAnyParser()
  }
}

/// Return a factory function that produces ``Command`` parsers.
///
/// See the above `makeParser` discussion
fileprivate func makeParser(
  for f: @escaping (
    Command.Bound
  ) -> Command
) -> (CommandDescriptor) -> AnyParser<Substring, Command> {
  return { (desc: CommandDescriptor) -> AnyParser<Substring, Command> in
    assert(desc.params.count == 1)
    assert(desc.params[0].kind == .bound)
    
    return WithParameters {
      Parse(f) {
        Parameter(desc.params[0].name, isLast: true) { Command.Bound.parser() }
      }
    }.eraseToAnyParser()
  }
}

// MARK: Command parsers

fileprivate struct WithParameters<Value: Parser>: Parser
where Value.Input == Substring {
  var value: Value
  
  let openBracket = Skip { "("; Prefix { $0.isWhitespace } }
  let closeBracket = Skip { Prefix { $0.isWhitespace }; ")" }
  
  init(
    @ParserBuilder value: () -> Value
  ) {
    self.value = value()
  }
  
  func parse(_ input: inout Value.Input) throws -> Value.Output {
    _ = try openBracket.parse(&input)
    let output = try value.parse(&input)
    _ = try closeBracket.parse(&input)
    
    return output
  }
}

fileprivate struct Parameter<Name: Parser, Value: Parser>: Parser
where Name.Output == Void,
      Name.Input == Substring,
      Name.Input == Value.Input {
  var parameterName: Name
  var value: Value
  var isLast: Bool
  
  let skipColon = Skip { Prefix { $0.isWhitespace }; ":"; Prefix { $0.isWhitespace } }
  let skipComma = Skip { Prefix { $0.isWhitespace }; ","; Prefix { $0.isWhitespace } }
  
  init(
    _ name: Name,
    isLast: Bool = false,
    @ParserBuilder value: () -> Value
  ) {
    self.parameterName = name
    self.value = value()
    self.isLast = isLast
  }
  
  func parse(_ input: inout Name.Input) throws -> Value.Output {
    _ = try parameterName.parse(&input)
    _ = try skipColon.parse(&input)
    let value = try value.parse(&input)
    if !isLast {
      _ = try skipComma.parse(&input)
    }
    return value
  }
}

// MARK: Processing the parserDefinitions

/// Build the hash table to be used by ``CommandParser``
///
/// This function walks the ``parserDefinitions``, parses each of them, and uses the resulting ``CommandDescriptor`` to build the parser for a given command.
///
/// - Note: This intentionally fails when a parser's definition string fails to parse. You're not supposed to provide incorrect command definitions in your table of ``parserDefinitions``, so you want this to blow up on you!
fileprivate func makeCommandParsers() -> [String : AnyParser<Substring, Command>] {
  var results: [String : AnyParser<Substring, Command>] = [:]
  for (commandDefinition, builder) in parserDefinitions {
    let desc = try! commandDescParser.parse(commandDefinition)
    
    results[desc.name] = builder(desc)
  }
  
  return results
}

fileprivate let commandDescParser = Parse(CommandDescriptor.init(name:params:)) {
  Prefix { !($0 == "(" || $0.isWhitespace) }.map(String.init)
  Skip { Prefix { $0.isWhitespace }; "("; Prefix { $0.isWhitespace } }
  Many { parameterParser } separator: { Skip { Prefix { $0.isWhitespace }; ","; Prefix { $0.isWhitespace } } }
  Skip { Prefix { $0.isWhitespace }; ")"; Prefix { $0.isWhitespace } }
}

fileprivate let parameterParser = Parse(ParameterDescriptor.init(name:kind:)) {
  Prefix { !($0 == ":" || $0.isWhitespace) }.map(String.init)
  Skip { Prefix { $0.isWhitespace }; ":"; Prefix { $0.isWhitespace } }
  ParameterDescriptor.Kind.parser()
}
